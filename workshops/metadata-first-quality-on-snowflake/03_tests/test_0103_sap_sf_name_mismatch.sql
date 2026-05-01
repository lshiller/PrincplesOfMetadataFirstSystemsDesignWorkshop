-- =============================================================================
-- test_0103_sap_sf_name_mismatch.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 03-E — Business test: SAP customer name matches Salesforce account name
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- Test ID : 103
-- Type    : BUSINESS
-- Question: For every (SAP customer, Salesforce account) pair joined on
--           SAP_CUSTOMER_ID, do the names match (case-insensitive, trimmed)?
--           Name drift signals un-synced master data.
--
-- PASS: 0 rows  → all matched pairs have consistent names
-- FAIL: 1 row per mismatched (SAP customer, SF account) pair
--
-- Expected failures with workshop seed data:
--   SAP 1002 "Globex Inc" ↔ SF A002 "Globex Incorporated" — name mismatch
--
-- Note: Where Test 102 finds duplicate mappings (e.g. SAP 1004), this test
-- will also surface both SF accounts. Fix Test 102 first to reduce noise.
--
-- Principles:
--   Non-contentful – comparison is normalised (UPPER + TRIM); tolerant of
--                    trivial whitespace differences
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;

CREATE OR REPLACE VIEW QUALITY.PUBLIC.TEST_103 AS
SELECT
    103                                                                  AS TEST_ID,
    'SAP/Salesforce Account Name Consistent'                             AS TEST_NAME,
    'Customer name differs between SAP and Salesforce'                   AS FAILURE_REASON,
    c.SAP_CUSTOMER_ID::VARCHAR                                           AS RECORD_KEY,
    OBJECT_CONSTRUCT(
        'sap_customer_id',   c.SAP_CUSTOMER_ID,
        'sap_customer_name', c.CUSTOMER_NAME,
        'sf_account_id',     a.SF_ACCOUNT_ID,
        'sf_account_name',   a.ACCOUNT_NAME
    )                                                                    AS RECORD_PAYLOAD,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ          AS DETECTED_AT
FROM CURATED.SAP.CUSTOMER c
JOIN CURATED.SALESFORCE.ACCOUNT a
     ON a.SAP_CUSTOMER_ID = c.SAP_CUSTOMER_ID
WHERE UPPER(TRIM(c.CUSTOMER_NAME)) != UPPER(TRIM(a.ACCOUNT_NAME));

-- ── Quick check (1 row expected: Globex Inc vs Globex Incorporated) ──────────
-- SELECT * FROM QUALITY.PUBLIC.TEST_103;
