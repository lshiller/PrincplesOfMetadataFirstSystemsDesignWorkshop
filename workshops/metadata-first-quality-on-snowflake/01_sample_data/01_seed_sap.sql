-- =============================================================================
-- 01_seed_sap.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 01-B — SAP seed data
-- Run as: DATA_ENGINEER or ACCOUNTADMIN
--
-- Intentional data issues (for workshop exercises):
--   • Customer 1003 (Initech LLC) has NO matching Salesforce account
--     → Test 101 (SAP Customer Missing in Salesforce) will FAIL for this row.
--   • Customer 1004 (Umbrella Co) maps to TWO Salesforce accounts
--     → Test 102 (No Duplicate SAP-to-SF Mapping) will FAIL for this customer.
--   • Customer 1002 (Globex Inc) has a name mismatch with its SF account
--     → Test 103 (SAP/Salesforce Account Name Match) will FAIL for this row.
-- =============================================================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE CURATED;

-- ── Truncate for idempotent re-seeding ────────────────────────────────────────
TRUNCATE TABLE CURATED.SAP.CUSTOMER;
TRUNCATE TABLE CURATED.SAP.SALES_ORDER;

-- ── CURATED.SAP.CUSTOMER ──────────────────────────────────────────────────────
INSERT INTO CURATED.SAP.CUSTOMER (SAP_CUSTOMER_ID, CUSTOMER_NAME, EMAIL, LAST_UPDATED_AT)
VALUES
    (1001, 'Acme Corp',    'acme@example.com',     '2025-01-01 00:00:00'::TIMESTAMP_NTZ),
    (1002, 'Globex Inc',   'globex@example.com',   '2025-01-15 00:00:00'::TIMESTAMP_NTZ),
    -- 1003 intentionally absent from Salesforce (triggers Test 101)
    (1003, 'Initech LLC',  'initech@example.com',  '2025-02-01 00:00:00'::TIMESTAMP_NTZ),
    -- 1004 mapped to two SF accounts (triggers Test 102)
    (1004, 'Umbrella Co',  'umbrella@example.com', '2025-03-01 00:00:00'::TIMESTAMP_NTZ);

-- ── CURATED.SAP.SALES_ORDER ───────────────────────────────────────────────────
INSERT INTO CURATED.SAP.SALES_ORDER (SAP_ORDER_ID, SAP_CUSTOMER_ID, AMOUNT, ORDER_DATE, LAST_UPDATED_AT)
VALUES
    (5001, 1001,  500.00, '2025-01-15', '2025-01-15 00:00:00'::TIMESTAMP_NTZ),
    (5002, 1002,  250.00, '2025-02-20', '2025-02-20 00:00:00'::TIMESTAMP_NTZ),
    (5003, 1003,  750.00, '2025-03-10', '2025-03-10 00:00:00'::TIMESTAMP_NTZ),
    (5004, 1004,  100.00, '2025-04-05', '2025-04-05 00:00:00'::TIMESTAMP_NTZ);

-- ── Verify ────────────────────────────────────────────────────────────────────
SELECT 'CURATED.SAP.CUSTOMER'    AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM CURATED.SAP.CUSTOMER
UNION ALL
SELECT 'CURATED.SAP.SALES_ORDER' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM CURATED.SAP.SALES_ORDER;
