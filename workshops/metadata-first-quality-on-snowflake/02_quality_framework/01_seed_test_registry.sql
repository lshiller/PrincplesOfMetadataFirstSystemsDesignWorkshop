-- =============================================================================
-- 01_seed_test_registry.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 02-B — Register example tests in QUALITY.PUBLIC.TEST
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- Test ID conventions:
--   1–99    – METADATA tests (framework compliance)
--   100–199 – BUSINESS tests for SAP ↔ Salesforce cross-system checks
--   200+    – reserved for participant exercises
--
-- Principles applied:
--   CoC  – ID ranges encode the test category; no runtime type-guessing needed
--   DRY  – all test behaviour (severity, action, proc) lives here; proc reads it
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE QUALITY;
USE SCHEMA PUBLIC;

-- Idempotent: delete existing seed rows before re-inserting
DELETE FROM QUALITY.PUBLIC.TEST WHERE ID IN (1, 2, 101, 102, 103);

INSERT INTO QUALITY.PUBLIC.TEST
    (ID,  NAME,                                    TEST_TYPE,   DESCRIPTION,
     SEVERITY, ENABLED, ON_FAIL_ACTION, ON_FAIL_PROC_NAME)
VALUES
-- ── Metadata tests ────────────────────────────────────────────────────────────
    (  1, 'Enabled Tests Have Views',
         'METADATA',
         'Every ENABLED test must have a corresponding view QUALITY.PUBLIC.TEST_{ID}. '
         'Fail = a test is registered but its view has not been created yet.',
         'HIGH', TRUE, 'NOTIFY', NULL),

    (  2, 'Test Views Expose Contract Columns',
         'METADATA',
         'Every existing test view must expose the six standard failure-contract columns: '
         'TEST_ID, TEST_NAME, FAILURE_REASON, RECORD_KEY, RECORD_PAYLOAD, DETECTED_AT. '
         'Fail = a view is missing one or more required columns.',
         'HIGH', TRUE, 'NOTIFY', NULL),

-- ── Business tests ────────────────────────────────────────────────────────────
    (101, 'SAP Customer Missing in Salesforce',
         'BUSINESS',
         'Every active SAP customer must have at least one mapped Salesforce account '
         '(via CURATED.SALESFORCE.ACCOUNT.SAP_CUSTOMER_ID). '
         'Fail = a SAP customer has no SF account.',
         'HIGH', TRUE, 'CALL_PROC', 'QUALITY.PUBLIC.ON_FAIL_STUB'),

    (102, 'No Duplicate SAP-to-Salesforce Account Mapping',
         'BUSINESS',
         'Each SAP_CUSTOMER_ID must appear in CURATED.SALESFORCE.ACCOUNT at most once. '
         'Duplicate mappings cause incorrect aggregations and attribution errors. '
         'Fail = a SAP customer is mapped to more than one SF account.',
         'HIGH', TRUE, 'NOTIFY', NULL),

    (103, 'SAP/Salesforce Account Name Consistent',
         'BUSINESS',
         'CURATED.SAP.CUSTOMER.CUSTOMER_NAME must equal CURATED.SALESFORCE.ACCOUNT.ACCOUNT_NAME '
         '(case-insensitive, trimmed). Name drift indicates unsynced master data. '
         'Fail = a matched pair has differing names.',
         'MEDIUM', TRUE, 'NOTIFY', NULL);

-- ── Verify ────────────────────────────────────────────────────────────────────
SELECT ID, NAME, TEST_TYPE, SEVERITY, ENABLED, ON_FAIL_ACTION
FROM   QUALITY.PUBLIC.TEST
ORDER  BY ID;
