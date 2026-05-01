-- =============================================================================
-- 02_seed_salesforce.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 01-C — Salesforce seed data
-- Run as: DATA_ENGINEER or ACCOUNTADMIN
--
-- Intentional data issues (for workshop exercises):
--   • SF Account A002 maps to SAP 1002 but uses "Globex Incorporated"
--     while SAP says "Globex Inc"
--     → Test 103 (SAP/Salesforce Account Name Match) will FAIL for this row.
--   • SF Accounts A003 AND A004 both map to SAP 1004 (duplicate mapping)
--     → Test 102 (No Duplicate SAP-to-SF Mapping) will FAIL for SAP 1004.
--   • No SF account for SAP 1003 (Initech LLC)
--     → Test 101 (SAP Customer Missing in Salesforce) will FAIL for this row.
-- =============================================================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE CURATED;

-- ── Truncate for idempotent re-seeding ────────────────────────────────────────
TRUNCATE TABLE CURATED.SALESFORCE.ACCOUNT;
TRUNCATE TABLE CURATED.SALESFORCE.USER;

-- ── CURATED.SALESFORCE.ACCOUNT ────────────────────────────────────────────────
INSERT INTO CURATED.SALESFORCE.ACCOUNT (SF_ACCOUNT_ID, SAP_CUSTOMER_ID, ACCOUNT_NAME, IS_ACTIVE, LAST_UPDATED_AT)
VALUES
    -- A001 → SAP 1001 (Acme Corp): name matches exactly — all tests pass
    ('A001', 1001, 'Acme Corp',          TRUE,  '2025-01-01 00:00:00'::TIMESTAMP_NTZ),
    -- A002 → SAP 1002: name MISMATCH ("Globex Incorporated" vs SAP "Globex Inc") — Test 103 FAILS
    ('A002', 1002, 'Globex Incorporated', TRUE,  '2025-01-15 00:00:00'::TIMESTAMP_NTZ),
    -- A003 → SAP 1004: first of duplicate mapping — Test 102 FAILS
    ('A003', 1004, 'Umbrella Co',         TRUE,  '2025-03-01 00:00:00'::TIMESTAMP_NTZ),
    -- A004 → SAP 1004: second of duplicate mapping — Test 102 FAILS
    ('A004', 1004, 'Umbrella Company',    TRUE,  '2025-03-15 00:00:00'::TIMESTAMP_NTZ);
    -- NOTE: SAP 1003 (Initech LLC) has no entry here — Test 101 FAILS

-- ── CURATED.SALESFORCE.USER ───────────────────────────────────────────────────
INSERT INTO CURATED.SALESFORCE.USER (SF_USER_ID, EMAIL, FULL_NAME, IS_ACTIVE, LAST_UPDATED_AT)
VALUES
    ('U001', 'alice@example.com',   'Alice Smith',   TRUE,  '2025-01-01 00:00:00'::TIMESTAMP_NTZ),
    ('U002', 'bob@example.com',     'Bob Jones',     TRUE,  '2025-01-01 00:00:00'::TIMESTAMP_NTZ),
    ('U003', 'charlie@example.com', 'Charlie Brown', FALSE, '2025-01-01 00:00:00'::TIMESTAMP_NTZ);

-- ── Verify ────────────────────────────────────────────────────────────────────
SELECT 'CURATED.SALESFORCE.ACCOUNT' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM CURATED.SALESFORCE.ACCOUNT
UNION ALL
SELECT 'CURATED.SALESFORCE.USER'    AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM CURATED.SALESFORCE.USER;
