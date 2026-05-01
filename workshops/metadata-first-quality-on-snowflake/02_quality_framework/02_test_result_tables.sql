-- =============================================================================
-- 02_test_result_tables.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 02-C — Run persistence and notification outbox DDL
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- Tables created:
--   QUALITY.TEST_RESULT.TEST_RESULT         – one row per test execution
--   QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX – intent queue for failure notifications
--
-- Dynamic failure tables (created at run-time by the stored procedure):
--   QUALITY.TEST_RESULT.TEST_{ID}_FAIL_{STAMP}
--   These are created as permanent tables so a separate cleanup process can
--   manage retention independently. STAMP format: YYYYMMDD_HH24MISS_FF3.
--
-- Principles applied:
--   CoC  – timestamp values stored as epoch milliseconds (NUMBER) for portability
--   DRY  – STATUS and ON_FAIL_ACTION are CHECK-constrained enums; no magic strings
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE QUALITY;
USE SCHEMA TEST_RESULT;

-- ── QUALITY.TEST_RESULT.TEST_RESULT ──────────────────────────────────────────
CREATE OR REPLACE TABLE QUALITY.TEST_RESULT.TEST_RESULT (
    ID          NUMBER(38,0)  NOT NULL AUTOINCREMENT,

    -- Foreign-key context (denormalised for query convenience)
    TEST_ID     NUMBER(38,0)  NOT NULL,
    TEST_NAME   VARCHAR(255)  NOT NULL,

    -- Timing — epoch milliseconds (DATE_PART(EPOCH_MILLISECOND, ...))
    START_TIME  NUMBER(38,0)  NOT NULL,
    END_TIME    NUMBER(38,0),
    RUN_TIME    NUMBER(38,0),          -- END_TIME - START_TIME

    -- Lifecycle state
    STATUS      VARCHAR(20)   NOT NULL DEFAULT 'STARTED'
                    CHECK (STATUS IN ('STARTED', 'ABORTED', 'COMPLETED')),
    TEST_PASSED BOOLEAN,               -- NULL while STARTED/ABORTED with no result

    CONSTRAINT PK_TEST_RESULT PRIMARY KEY (ID)
)
COMMENT = 'One row per test execution. STATUS transitions: STARTED → COMPLETED | ABORTED. '
          'Timing columns store epoch milliseconds for easy arithmetic.';

-- ── QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX ───────────────────────────────────
CREATE OR REPLACE TABLE QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX (
    ID              NUMBER(38,0)  NOT NULL AUTOINCREMENT,

    -- Traceability
    TEST_RESULT_ID  NUMBER(38,0)  NOT NULL,  -- FK → QUALITY.TEST_RESULT.TEST_RESULT.ID
    TEST_ID         NUMBER(38,0)  NOT NULL,  -- denormalised for direct lookup
    TEST_NAME       VARCHAR(255)  NOT NULL,
    SEVERITY        VARCHAR(10),

    -- Payload
    FAIL_TABLE_NAME VARCHAR(500),            -- e.g. QUALITY.TEST_RESULT.TEST_101_FAIL_20260501_224935_123
    MESSAGE         VARCHAR(2000),

    -- Lifecycle
    CREATED_AT      TIMESTAMP_NTZ NOT NULL DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
    SENT_AT         TIMESTAMP_NTZ,           -- NULL = pending; set by a downstream notification process

    CONSTRAINT PK_NOTIFICATION_OUTBOX PRIMARY KEY (ID)
)
COMMENT = 'Notification intent queue. The orchestration proc inserts a row here when a test fails '
          'and ON_FAIL_ACTION is NOTIFY or CALL_PROC. A separate process reads pending rows '
          '(SENT_AT IS NULL) and delivers notifications, then sets SENT_AT.';

-- ── Verify ────────────────────────────────────────────────────────────────────
SHOW TABLES IN SCHEMA QUALITY.TEST_RESULT;
