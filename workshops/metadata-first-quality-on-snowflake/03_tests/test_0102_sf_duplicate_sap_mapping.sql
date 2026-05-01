-- =============================================================================
-- test_0102_sf_duplicate_sap_mapping.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 03-D — Business test: no duplicate SAP-to-Salesforce account mappings
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- Test ID : 102
-- Type    : BUSINESS
-- Question: Does any SAP_CUSTOMER_ID appear more than once in
--           CURATED.SALESFORCE.ACCOUNT?
--           A duplicate mapping causes double-counting in aggregations.
--
-- PASS: 0 rows  → each SAP customer maps to at most one SF account
-- FAIL: 1 row per SAP customer that maps to more than one SF account
--
-- Expected failures with workshop seed data:
--   SAP_CUSTOMER_ID = 1004 (Umbrella Co) — mapped to both A003 and A004
--
-- Principles:
--   DRY  – ARRAY_AGG captures all offending SF account IDs in one payload row
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;

CREATE OR REPLACE VIEW QUALITY.PUBLIC.TEST_102 AS
WITH dup_mappings AS (
    SELECT
        SAP_CUSTOMER_ID,
        COUNT(*)                    AS SF_ACCOUNT_COUNT,
        ARRAY_AGG(SF_ACCOUNT_ID)    AS SF_ACCOUNT_IDS
    FROM   CURATED.SALESFORCE.ACCOUNT
    WHERE  SAP_CUSTOMER_ID IS NOT NULL
    GROUP  BY SAP_CUSTOMER_ID
    HAVING COUNT(*) > 1
)
SELECT
    102                                                                  AS TEST_ID,
    'No Duplicate SAP-to-Salesforce Account Mapping'                     AS TEST_NAME,
    'SAP customer mapped to ' || d.SF_ACCOUNT_COUNT::VARCHAR
        || ' Salesforce accounts'                                        AS FAILURE_REASON,
    d.SAP_CUSTOMER_ID::VARCHAR                                           AS RECORD_KEY,
    OBJECT_CONSTRUCT(
        'sap_customer_id',   d.SAP_CUSTOMER_ID,
        'sf_account_count',  d.SF_ACCOUNT_COUNT,
        'sf_account_ids',    d.SF_ACCOUNT_IDS
    )                                                                    AS RECORD_PAYLOAD,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ          AS DETECTED_AT
FROM dup_mappings d;

-- ── Quick check (1 row expected: SAP 1004 / Umbrella Co) ──────────────────────
-- SELECT * FROM QUALITY.PUBLIC.TEST_102;
