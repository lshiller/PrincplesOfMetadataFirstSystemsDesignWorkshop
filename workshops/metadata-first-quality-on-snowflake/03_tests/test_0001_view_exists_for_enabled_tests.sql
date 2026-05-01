-- =============================================================================
-- test_0001_view_exists_for_enabled_tests.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 03-A — Metadata test: every enabled test has a view
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- Test ID : 1
-- Type    : METADATA
-- Question: Is QUALITY.PUBLIC.TEST_{ID} present in the catalog for every
--           enabled test row in QUALITY.PUBLIC.TEST?
--
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  FAILURE CONTRACT  (all test views must honour this column set)         ║
-- ║  TEST_ID        NUMBER   – matches QUALITY.PUBLIC.TEST.ID              ║
-- ║  TEST_NAME      VARCHAR  – matches QUALITY.PUBLIC.TEST.NAME            ║
-- ║  FAILURE_REASON VARCHAR  – human-readable description of the failure   ║
-- ║  RECORD_KEY     VARCHAR  – identifying key of the failing record        ║
-- ║  RECORD_PAYLOAD VARIANT  – structured JSON detail (OBJECT_CONSTRUCT)   ║
-- ║  DETECTED_AT    TIMESTAMP_NTZ – when the anomaly was detected          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- PASS: 0 rows  → every enabled test has a corresponding view
-- FAIL: 1 row per enabled test that is missing its view
--
-- Principle: CoC — conventions are self-enforcing; missing a view is a
--            metadata violation surfaced by the framework itself.
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;

CREATE OR REPLACE VIEW QUALITY.PUBLIC.TEST_1 AS
SELECT
    t.ID                                                            AS TEST_ID,
    t.NAME                                                          AS TEST_NAME,
    'No view found: QUALITY.PUBLIC.TEST_' || t.ID::VARCHAR          AS FAILURE_REASON,
    t.ID::VARCHAR                                                   AS RECORD_KEY,
    OBJECT_CONSTRUCT(
        'test_id',       t.ID,
        'test_name',     t.NAME,
        'view_expected', 'QUALITY.PUBLIC.TEST_' || t.ID::VARCHAR
    )                                                               AS RECORD_PAYLOAD,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ     AS DETECTED_AT
FROM QUALITY.PUBLIC.TEST t
WHERE t.ENABLED = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM   QUALITY.INFORMATION_SCHEMA.VIEWS v
      WHERE  v.TABLE_SCHEMA = 'PUBLIC'
        AND  v.TABLE_NAME   = 'TEST_' || t.ID::VARCHAR
  );

-- ── Quick check (should return 4 rows for tests 2, 101, 102, 103 ──────────────
-- until their views are created in subsequent scripts)
-- SELECT * FROM QUALITY.PUBLIC.TEST_1;
