-- =============================================================================
-- test_0002_view_contract_columns.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 03-B — Metadata test: existing test views expose all contract columns
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- Test ID : 2
-- Type    : METADATA
-- Question: For every enabled test that already has a view, does the view
--           expose all six columns required by the failure contract?
--
-- Required columns (the "failure contract"):
--   TEST_ID, TEST_NAME, FAILURE_REASON, RECORD_KEY, RECORD_PAYLOAD, DETECTED_AT
--
-- This test works in tandem with Test 1:
--   Test 1 catches MISSING views.
--   Test 2 catches PRESENT but NON-CONFORMING views.
--
-- PASS: 0 rows  → all existing test views are contract-compliant
-- FAIL: 1 row per (test_id, missing_column) pair
--
-- Principles:
--   DRY  – required column list lives in one place (the PARSE_JSON literal below)
--   CoC  – the framework enforces its own naming convention via metadata
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;

CREATE OR REPLACE VIEW QUALITY.PUBLIC.TEST_2 AS
WITH
-- Single source of truth for the failure-contract column names
required_cols AS (
    SELECT f.VALUE::VARCHAR AS COL_NAME
    FROM   TABLE(FLATTEN(PARSE_JSON(
               '["TEST_ID","TEST_NAME","FAILURE_REASON","RECORD_KEY","RECORD_PAYLOAD","DETECTED_AT"]'
           ))) f
),

-- Enabled tests that already have a view (inner join skips missing views)
enabled_test_views AS (
    SELECT t.ID   AS TEST_ID,
           t.NAME AS TEST_NAME
    FROM   QUALITY.PUBLIC.TEST t
    JOIN   QUALITY.INFORMATION_SCHEMA.VIEWS v
           ON  v.TABLE_SCHEMA = 'PUBLIC'
           AND v.TABLE_NAME   = 'TEST_' || t.ID::VARCHAR
    WHERE  t.ENABLED = TRUE
),

-- Columns that actually exist in each test view (upper-cased for comparison)
actual_cols AS (
    SELECT etv.TEST_ID,
           UPPER(c.COLUMN_NAME) AS COL_NAME
    FROM   enabled_test_views etv
    JOIN   QUALITY.INFORMATION_SCHEMA.COLUMNS c
           ON  c.TABLE_SCHEMA = 'PUBLIC'
           AND c.TABLE_NAME   = 'TEST_' || etv.TEST_ID::VARCHAR
)

SELECT
    etv.TEST_ID,
    etv.TEST_NAME,
    'View QUALITY.PUBLIC.TEST_' || etv.TEST_ID::VARCHAR
        || ' is missing required column: ' || rc.COL_NAME               AS FAILURE_REASON,
    etv.TEST_ID::VARCHAR                                                 AS RECORD_KEY,
    OBJECT_CONSTRUCT(
        'test_id',         etv.TEST_ID,
        'view_name',       'QUALITY.PUBLIC.TEST_' || etv.TEST_ID::VARCHAR,
        'missing_column',  rc.COL_NAME
    )                                                                    AS RECORD_PAYLOAD,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ          AS DETECTED_AT
FROM enabled_test_views etv
CROSS JOIN required_cols rc
WHERE NOT EXISTS (
    SELECT 1
    FROM   actual_cols ac
    WHERE  ac.TEST_ID  = etv.TEST_ID
      AND  ac.COL_NAME = rc.COL_NAME
);

-- ── Quick check (0 rows expected once all views in 03_tests are created) ─────
-- SELECT * FROM QUALITY.PUBLIC.TEST_2;
