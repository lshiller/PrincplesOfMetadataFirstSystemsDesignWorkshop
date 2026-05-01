-- =============================================================================
-- 00_curated_tables.sql
-- Workshop: Metadata-First Data Quality on Snowflake
-- Step  : 01-A — Source-system DDL (CURATED database)
-- Run as: DATA_ENGINEER or ACCOUNTADMIN
--
-- Tables created:
--   CURATED.SAP.CUSTOMER        – SAP master customer records
--   CURATED.SAP.SALES_ORDER     – SAP sales orders
--   CURATED.SALESFORCE.ACCOUNT  – Salesforce Account records
--   CURATED.SALESFORCE.USER     – Salesforce User records
--
-- Principles applied:
--   CoC  – all curated tables use CREATED_AT / LAST_UPDATED_AT conventions
--   DRY  – timestamps default to UTC so every table is consistent
-- =============================================================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE CURATED;

-- ── CURATED.SAP ───────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE CURATED.SAP.CUSTOMER (
    SAP_CUSTOMER_ID  NUMBER(38,0)   NOT NULL,
    CUSTOMER_NAME    VARCHAR(255)   NOT NULL,
    EMAIL            VARCHAR(255),
    LAST_UPDATED_AT  TIMESTAMP_NTZ  NOT NULL DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
    CONSTRAINT PK_SAP_CUSTOMER PRIMARY KEY (SAP_CUSTOMER_ID)
)
COMMENT = 'Master customer records extracted from SAP ERP.';

CREATE OR REPLACE TABLE CURATED.SAP.SALES_ORDER (
    SAP_ORDER_ID     NUMBER(38,0)   NOT NULL,
    SAP_CUSTOMER_ID  NUMBER(38,0)   NOT NULL,
    AMOUNT           NUMBER(12,2)   NOT NULL,
    ORDER_DATE       DATE           NOT NULL,
    LAST_UPDATED_AT  TIMESTAMP_NTZ  NOT NULL DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
    CONSTRAINT PK_SAP_SALES_ORDER PRIMARY KEY (SAP_ORDER_ID)
)
COMMENT = 'Sales orders extracted from SAP ERP.';

-- ── CURATED.SALESFORCE ────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE CURATED.SALESFORCE.ACCOUNT (
    SF_ACCOUNT_ID    VARCHAR(18)    NOT NULL,
    SAP_CUSTOMER_ID  NUMBER(38,0),               -- cross-system mapping field
    ACCOUNT_NAME     VARCHAR(255)   NOT NULL,
    IS_ACTIVE        BOOLEAN        NOT NULL DEFAULT TRUE,
    LAST_UPDATED_AT  TIMESTAMP_NTZ  NOT NULL DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
    CONSTRAINT PK_SF_ACCOUNT PRIMARY KEY (SF_ACCOUNT_ID)
)
COMMENT = 'Account records extracted from Salesforce CRM. SAP_CUSTOMER_ID is the cross-system mapping key.';

CREATE OR REPLACE TABLE CURATED.SALESFORCE.USER (
    SF_USER_ID       VARCHAR(18)    NOT NULL,
    EMAIL            VARCHAR(255)   NOT NULL,
    FULL_NAME        VARCHAR(255),
    IS_ACTIVE        BOOLEAN        NOT NULL DEFAULT TRUE,
    LAST_UPDATED_AT  TIMESTAMP_NTZ  NOT NULL DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
    CONSTRAINT PK_SF_USER PRIMARY KEY (SF_USER_ID)
)
COMMENT = 'User records extracted from Salesforce CRM.';

-- ── Verify ────────────────────────────────────────────────────────────────────
SHOW TABLES IN SCHEMA CURATED.SAP;
SHOW TABLES IN SCHEMA CURATED.SALESFORCE;
