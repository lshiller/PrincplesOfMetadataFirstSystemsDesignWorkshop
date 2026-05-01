-- =============================================================================
-- 01_databases_and_schemas.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 00-B — Database and schema scaffolding
-- Run as: ACCOUNTADMIN (or SYSADMIN)
--
-- Databases created:
--   QUALITY  — test registry, run results, outbox
--   CURATED  — curated source-system data (SAP, Salesforce)
--
-- Principles applied:
--   CoC  – schema names reflect the source system / concern they serve
--   DRY  – both databases are created with the same idempotent pattern
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WORKSHOP_WH;

-- ── QUALITY database ──────────────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS QUALITY
    DATA_RETENTION_TIME_IN_DAYS = 1
    COMMENT = 'Metadata-first data quality framework: test registry, run results, and notification outbox.';

CREATE SCHEMA IF NOT EXISTS QUALITY.PUBLIC
    COMMENT = 'Test registry (QUALITY.PUBLIC.TEST) and all test views (QUALITY.PUBLIC.TEST_{ID}).';

CREATE SCHEMA IF NOT EXISTS QUALITY.TEST_RESULT
    COMMENT = 'Persisted run metadata, failure snapshot tables, and notification outbox.';

-- ── CURATED database ──────────────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS CURATED
    DATA_RETENTION_TIME_IN_DAYS = 1
    COMMENT = 'Curated source-system data used by quality tests.';

CREATE SCHEMA IF NOT EXISTS CURATED.SAP
    COMMENT = 'Curated tables sourced from the SAP ERP system.';

CREATE SCHEMA IF NOT EXISTS CURATED.SALESFORCE
    COMMENT = 'Curated tables sourced from Salesforce CRM.';

-- ── Verify ────────────────────────────────────────────────────────────────────
SHOW DATABASES LIKE 'QUALITY';
SHOW DATABASES LIKE 'CURATED';
SHOW SCHEMAS   IN DATABASE QUALITY;
SHOW SCHEMAS   IN DATABASE CURATED;
