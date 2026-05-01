-- =============================================================================
-- 00_run_all_tests_procedure.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 04-A — Orchestration stored procedure
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- QUALITY.PUBLIC.RUN_ALL_TESTS(RUN_NOTE, ONLY_TEST_TYPE, DRY_RUN)
--
-- Parameters:
--   RUN_NOTE        VARCHAR  – free-text label for this run (optional)
--   ONLY_TEST_TYPE  VARCHAR  – 'METADATA' | 'BUSINESS' | NULL (run all)
--   DRY_RUN         BOOLEAN  – TRUE = count rows only; skip materialising failure
--                              tables and outbox entries (default FALSE)
--
-- Per-test behaviour (sequential):
--   1. INSERT STARTED row into QUALITY.TEST_RESULT.TEST_RESULT
--   2. COUNT(*) from QUALITY.PUBLIC.TEST_{ID} via dynamic SQL
--   3. If fail AND NOT dry_run:
--        a. CREATE TABLE QUALITY.TEST_RESULT.TEST_{ID}_FAIL_{STAMP}
--             AS SELECT * FROM QUALITY.PUBLIC.TEST_{ID}
--        b. INSERT notification intent into QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX
--        c. CALL ON_FAIL_PROC_NAME if ON_FAIL_ACTION = 'CALL_PROC' (metadata-driven)
--   4. UPDATE TEST_RESULT row: END_TIME, RUN_TIME, STATUS='COMPLETED', TEST_PASSED
--   5. On exception: UPDATE STATUS='ABORTED', TEST_PASSED=FALSE
--
-- Returns: summary string, e.g. "Completed | Passed: 2 | Failed: 3 | Aborted: 0"
--
-- Principles applied:
--   CoC  – view names are derived: 'QUALITY.PUBLIC.TEST_' || ID (never hardcoded)
--   DRY  – all per-test behaviour is driven by TEST.ON_FAIL_ACTION metadata
--   Non-contentful – no test IDs or business logic hardcoded in this procedure
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;

CREATE OR REPLACE PROCEDURE QUALITY.PUBLIC.RUN_ALL_TESTS(
    RUN_NOTE        VARCHAR  DEFAULT NULL,
    ONLY_TEST_TYPE  VARCHAR  DEFAULT NULL,   -- NULL = all; 'METADATA' or 'BUSINESS'
    DRY_RUN         BOOLEAN  DEFAULT FALSE    -- TRUE = skip failure materialisation
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    -- ── Cursor: all enabled tests, ordered by ID (sequential execution) ───────
    c_tests CURSOR FOR
        SELECT ID, NAME, TEST_TYPE, SEVERITY, ON_FAIL_ACTION, ON_FAIL_PROC_NAME
        FROM   QUALITY.PUBLIC.TEST
        WHERE  ENABLED = TRUE
        ORDER  BY ID;

    -- ── Working variables ─────────────────────────────────────────────────────
    v_test_id        NUMBER(38,0);
    v_test_name      VARCHAR;
    v_test_type      VARCHAR;
    v_severity       VARCHAR;
    v_on_fail_action VARCHAR;
    v_on_fail_proc   VARCHAR;

    v_result_id      NUMBER(38,0);
    v_start_ms       NUMBER(38,0);
    v_end_ms         NUMBER(38,0);
    v_row_count      NUMBER(38,0);

    v_view_name      VARCHAR;
    v_stamp          VARCHAR;
    v_fail_table     VARCHAR;
    v_dml            VARCHAR;
    v_passed         BOOLEAN;

    -- ── Run-level counters ────────────────────────────────────────────────────
    v_pass_count     NUMBER(38,0) DEFAULT 0;
    v_fail_count     NUMBER(38,0) DEFAULT 0;
    v_abort_count    NUMBER(38,0) DEFAULT 0;

BEGIN
    FOR rec IN c_tests DO

        -- ── Optional per-type filter (applied in scripting, not cursor SQL) ───
        -- This avoids bind-variable edge cases in cursor declarations while
        -- keeping the filter logic readable and metadata-driven.
        IF ONLY_TEST_TYPE IS NOT NULL AND rec.TEST_TYPE != ONLY_TEST_TYPE THEN
            CONTINUE;
        END IF;

        v_test_id        := rec.ID;
        v_test_name      := rec.NAME;
        v_test_type      := rec.TEST_TYPE;
        v_severity       := rec.SEVERITY;
        v_on_fail_action := rec.ON_FAIL_ACTION;
        v_on_fail_proc   := rec.ON_FAIL_PROC_NAME;

        -- CoC: view name is fully derived from test ID — never hardcoded
        v_view_name := 'QUALITY.PUBLIC.TEST_' || v_test_id::VARCHAR;
        v_start_ms  := DATE_PART(EPOCH_MILLISECOND, CURRENT_TIMESTAMP())::NUMBER(38,0);

        -- ── 1. Record STARTED ─────────────────────────────────────────────────
        INSERT INTO QUALITY.TEST_RESULT.TEST_RESULT
            (TEST_ID, TEST_NAME, START_TIME, STATUS)
        VALUES
            (:v_test_id, :v_test_name, :v_start_ms, 'STARTED');

        -- Retrieve the AUTOINCREMENT ID of the row we just inserted.
        -- Sequential execution guarantees this SELECT returns exactly one row.
        SELECT MAX(ID) INTO :v_result_id
        FROM   QUALITY.TEST_RESULT.TEST_RESULT
        WHERE  TEST_ID    = :v_test_id
          AND  START_TIME = :v_start_ms
          AND  STATUS     = 'STARTED';

        -- ── 2. Execute test + handle result ───────────────────────────────────
        -- Wrapped in BEGIN/EXCEPTION so one failing test never aborts the run.
        BEGIN

            -- Count failure rows via dynamic SQL (CoC: view name from metadata)
            v_dml       := 'SELECT COUNT(*) FROM ' || v_view_name;
            v_row_count := (EXECUTE IMMEDIATE :v_dml);
            v_passed    := (v_row_count = 0);

            IF NOT v_passed AND NOT DRY_RUN THEN

                -- ── 3a. Materialise failure snapshot table ────────────────────
                -- STAMP format: YYYYMMDD_HH24MISS_FF3  (safe identifier suffix)
                v_stamp      := TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS_FF3');
                v_fail_table := 'QUALITY.TEST_RESULT.TEST_' || v_test_id::VARCHAR
                                    || '_FAIL_' || v_stamp;

                v_dml := 'CREATE OR REPLACE TABLE ' || v_fail_table
                             || ' AS SELECT * FROM ' || v_view_name;
                EXECUTE IMMEDIATE :v_dml;

                -- ── 3b. Notification outbox entry ─────────────────────────────
                IF v_on_fail_action = 'NOTIFY' OR v_on_fail_action = 'CALL_PROC' THEN
                    INSERT INTO QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX
                        (TEST_RESULT_ID, TEST_ID, TEST_NAME, SEVERITY,
                         FAIL_TABLE_NAME, MESSAGE)
                    VALUES (
                        :v_result_id,
                        :v_test_id,
                        :v_test_name,
                        :v_severity,
                        :v_fail_table,
                        'FAILED | ' || :v_test_name
                            || ' | rows: '    || :v_row_count::VARCHAR
                            || ' | details: ' || :v_fail_table
                    );
                END IF;

                -- ── 3c. Metadata-driven automation stub ───────────────────────
                -- ON_FAIL_PROC_NAME is stored in QUALITY.PUBLIC.TEST — no
                -- procedure names are hardcoded here (DRY + non-contentful).
                IF v_on_fail_action = 'CALL_PROC' AND v_on_fail_proc IS NOT NULL THEN
                    v_dml := 'CALL ' || v_on_fail_proc
                                 || '(' || v_result_id::VARCHAR || ')';
                    EXECUTE IMMEDIATE :v_dml;
                END IF;

            END IF;

            -- ── 4. Close out as COMPLETED ─────────────────────────────────────
            v_end_ms := DATE_PART(EPOCH_MILLISECOND, CURRENT_TIMESTAMP())::NUMBER(38,0);

            UPDATE QUALITY.TEST_RESULT.TEST_RESULT
               SET END_TIME    = :v_end_ms,
                   RUN_TIME    = :v_end_ms - :v_start_ms,
                   STATUS      = 'COMPLETED',
                   TEST_PASSED = :v_passed
             WHERE ID = :v_result_id;

            IF v_passed THEN
                v_pass_count := v_pass_count + 1;
            ELSE
                v_fail_count := v_fail_count + 1;
            END IF;

        EXCEPTION
            -- ── 5. Exception handler: mark ABORTED ───────────────────────────
            WHEN OTHER THEN
                v_end_ms := DATE_PART(EPOCH_MILLISECOND, CURRENT_TIMESTAMP())::NUMBER(38,0);

                UPDATE QUALITY.TEST_RESULT.TEST_RESULT
                   SET END_TIME    = :v_end_ms,
                       RUN_TIME    = :v_end_ms - :v_start_ms,
                       STATUS      = 'ABORTED',
                       TEST_PASSED = FALSE
                 WHERE ID = :v_result_id;

                v_abort_count := v_abort_count + 1;
        END;  -- inner BEGIN/EXCEPTION

    END FOR;

    RETURN 'Completed | Passed: '  || v_pass_count::VARCHAR
        || ' | Failed: '   || v_fail_count::VARCHAR
        || ' | Aborted: '  || v_abort_count::VARCHAR
        || CASE WHEN RUN_NOTE IS NOT NULL THEN ' | Note: ' || RUN_NOTE ELSE '' END;

END;
$$;

-- ── Usage examples ────────────────────────────────────────────────────────────
-- Run all enabled tests:
--   CALL QUALITY.PUBLIC.RUN_ALL_TESTS();
--
-- Run only METADATA tests (framework compliance first):
--   CALL QUALITY.PUBLIC.RUN_ALL_TESTS('metadata pass', 'METADATA');
--
-- Dry run (count rows, skip materialising failure tables):
--   CALL QUALITY.PUBLIC.RUN_ALL_TESTS('dry run', NULL, TRUE);
--
-- Inspect results:
--   SELECT * FROM QUALITY.TEST_RESULT.TEST_RESULT ORDER BY ID DESC;
--   SELECT * FROM QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX ORDER BY ID DESC;

-- ── Verify ────────────────────────────────────────────────────────────────────
SHOW PROCEDURES LIKE 'RUN_ALL_TESTS' IN SCHEMA QUALITY.PUBLIC;
