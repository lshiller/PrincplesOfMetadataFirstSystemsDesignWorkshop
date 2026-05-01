-- =============================================================================
-- 00_test_registry.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 02-A — QUALITY.PUBLIC.TEST table (the metadata registry)
-- Run as: METADATA_STEWARD or ACCOUNTADMIN
--
-- This table IS the product.  Every test view, every orchestration call,
-- every notification is driven by rows in this table.
--
-- Required columns (spec):
--   ID, NAME, CREATED_AT
--
-- Governance columns (metadata-first extensions):
--   TEST_TYPE        – METADATA (framework compliance) or BUSINESS (cross-system)
--   DESCRIPTION      – human-readable intent
--   OWNER_ROLE       – Snowflake role responsible for this test
--   SEVERITY         – LOW | MEDIUM | HIGH
--   ENABLED          – FALSE = skip during RUN_ALL_TESTS()
--   ON_FAIL_ACTION   – NONE | NOTIFY | CALL_PROC  (drives orchestration behaviour)
--   ON_FAIL_PROC_NAME– fully-qualified procedure to call when ON_FAIL_ACTION='CALL_PROC'
--
-- Principles applied:
--   CoC  – test views are always named QUALITY.PUBLIC.TEST_{ID}
--   DRY  – all orchestration derives behaviour from metadata fields; nothing hardcoded
--   Non-contentful code – defaults encode the convention so rows stay concise
-- =============================================================================

USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE QUALITY;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE QUALITY.PUBLIC.TEST (
    -- ── Required (spec) columns ───────────────────────────────────────────────
    ID                NUMBER(38,0)  NOT NULL,
    NAME              VARCHAR(255)  NOT NULL,
    CREATED_AT        TIMESTAMP_NTZ NOT NULL DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,

    -- ── Governance / metadata-first extensions ────────────────────────────────
    DESCRIPTION       VARCHAR(2000),
    TEST_TYPE         VARCHAR(20)   NOT NULL DEFAULT 'BUSINESS'
                          CHECK (TEST_TYPE IN ('METADATA', 'BUSINESS')),
    OWNER_ROLE        VARCHAR(255)  NOT NULL DEFAULT 'DATA_ENGINEER',
    SEVERITY          VARCHAR(10)   NOT NULL DEFAULT 'MEDIUM'
                          CHECK (SEVERITY IN ('LOW', 'MEDIUM', 'HIGH')),
    ENABLED           BOOLEAN       NOT NULL DEFAULT TRUE,

    -- ── Failure-action columns (metadata drives orchestration — no hardcoding) ─
    ON_FAIL_ACTION    VARCHAR(20)   NOT NULL DEFAULT 'NOTIFY'
                          CHECK (ON_FAIL_ACTION IN ('NONE', 'NOTIFY', 'CALL_PROC')),
    ON_FAIL_PROC_NAME VARCHAR(500),    -- e.g. 'QUALITY.PUBLIC.ON_FAIL_STUB'

    CONSTRAINT PK_TEST PRIMARY KEY (ID)
)
COMMENT = 'Central test registry. Each row defines one quality test. '
          'The convention is: SELECT * FROM QUALITY.PUBLIC.TEST_{ID} to run a test. '
          '0 rows = pass; >0 rows = fail (diagnostic rows).';

-- ── Verify ────────────────────────────────────────────────────────────────────
DESCRIBE TABLE QUALITY.PUBLIC.TEST;
