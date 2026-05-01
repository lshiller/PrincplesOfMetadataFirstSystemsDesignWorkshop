-- =============================================================================
-- test_0101_sap_customer_missing_in_sf.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 03-C — Business test: every SAP customer has a Salesforce account
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- Test ID : 101
-- Type    : BUSINESS
-- Question: Does every row in CURATED.SAP.CUSTOMER have at least one
--           matching row in CURATED.SALESFORCE.ACCOUNT
--           (joined on SAP_CUSTOMER_ID)?
--
-- PASS: 0 rows  → all SAP customers are represented in Salesforce
-- FAIL: 1 row per SAP customer with no matching Salesforce account
--
-- Expected failures with workshop seed data:
--   SAP_CUSTOMER_ID = 1003 (Initech LLC) — no SF account exists
--
-- Principles:
--   CoC  – joins on SAP_CUSTOMER_ID, the canonical cross-system mapping key
--   Non-contentful – the view never hardcodes IDs; it evaluates live data
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;

CREATE OR REPLACE VIEW QUALITY.PUBLIC.TEST_101 AS
SELECT
    101                                                                  AS TEST_ID,
    'SAP Customer Missing in Salesforce'                                 AS TEST_NAME,
    'SAP customer has no corresponding Salesforce account'               AS FAILURE_REASON,
    c.SAP_CUSTOMER_ID::VARCHAR                                           AS RECORD_KEY,
    OBJECT_CONSTRUCT(
        'sap_customer_id',  c.SAP_CUSTOMER_ID,
        'customer_name',    c.CUSTOMER_NAME,
        'email',            c.EMAIL
    )                                                                    AS RECORD_PAYLOAD,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ          AS DETECTED_AT
FROM CURATED.SAP.CUSTOMER c
WHERE NOT EXISTS (
    SELECT 1
    FROM   CURATED.SALESFORCE.ACCOUNT a
    WHERE  a.SAP_CUSTOMER_ID = c.SAP_CUSTOMER_ID
);

-- ── Quick check (1 row expected: Initech LLC / 1003) ─────────────────────────
-- SELECT * FROM QUALITY.PUBLIC.TEST_101;
