-- =============================================================================
-- 01_automation_stub_procedure.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 04-B — Automation stub for metadata-driven on-fail actions
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- QUALITY.PUBLIC.ON_FAIL_STUB(TEST_RESULT_ID NUMBER)
--
-- This procedure is referenced in QUALITY.PUBLIC.TEST.ON_FAIL_PROC_NAME for
-- tests where ON_FAIL_ACTION = 'CALL_PROC'. The orchestration procedure
-- QUALITY.PUBLIC.RUN_ALL_TESTS invokes it dynamically — the proc name is
-- read from metadata, never hardcoded.
--
-- In production you would replace (or extend) this stub with real logic:
--   • Reverse ETL: push corrections back to a source system
--   • Ticketing: create a Jira/ServiceNow incident via an API
--   • Alerting: invoke a Snowflake External Function → SNS/Slack
--   • Remediation: merge corrected records into a curated table
--
-- For the workshop the stub simply logs its invocation to an audit table
-- so participants can see the call chain without needing external services.
--
-- Principles applied:
--   CoC  – on-fail procedure signature: always (TEST_RESULT_ID NUMBER)
--   DRY  – one stub pattern; replace body only when promoting to production
--   Metadata-first – the *decision* to call this proc lives in TEST metadata,
--                    not in application code
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;

-- ── Audit log for stub invocations ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS QUALITY.TEST_RESULT.AUTOMATION_STUB_LOG (
    ID             NUMBER(38,0)  NOT NULL AUTOINCREMENT,
    TEST_RESULT_ID NUMBER(38,0)  NOT NULL,
    INVOKED_AT     TIMESTAMP_NTZ NOT NULL DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
    NOTE           VARCHAR,
    CONSTRAINT PK_AUTOMATION_STUB_LOG PRIMARY KEY (ID)
)
COMMENT = 'Audit trail for ON_FAIL_STUB invocations. Replace with real automation in production.';

-- ── Stub procedure ────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE QUALITY.PUBLIC.ON_FAIL_STUB(TEST_RESULT_ID NUMBER)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_note VARCHAR;
BEGIN
    -- In production, add reverse-ETL / alerting / ticketing logic here.
    -- The procedure receives TEST_RESULT_ID so it can look up the full
    -- test run context from QUALITY.TEST_RESULT.TEST_RESULT and any
    -- materialised failure table.

    v_note := 'Stub invoked for TEST_RESULT_ID=' || TEST_RESULT_ID::VARCHAR
                  || '. Replace this body with production automation.';

    INSERT INTO QUALITY.TEST_RESULT.AUTOMATION_STUB_LOG (TEST_RESULT_ID, NOTE)
    VALUES (:TEST_RESULT_ID, :v_note);

    RETURN v_note;
END;
$$;

-- ── Verify ────────────────────────────────────────────────────────────────────
SHOW PROCEDURES LIKE 'ON_FAIL_STUB' IN SCHEMA QUALITY.PUBLIC;

-- ── Workshop discussion prompt ────────────────────────────────────────────────
-- Q: What would you put in this procedure to automatically remediate
--    Test 101 failures (SAP customers missing in Salesforce)?
--
-- Example ideas:
--   • INSERT into a staging table that triggers a Salesforce upsert job
--   • Call an External Function that invokes an AWS Lambda / Azure Function
--   • Log a structured message to NOTIFICATION_OUTBOX for a human to review
--   • Update a metadata flag on QUALITY.PUBLIC.TEST to pause the test
--     while the root cause is investigated
