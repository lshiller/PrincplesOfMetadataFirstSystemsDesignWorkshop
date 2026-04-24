/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : 00_environment_setup.sql
  Purpose : Create all Snowflake infrastructure required for the workshop —
            warehouses, databases, schemas, and roles — before loading data.

  Run as  : ACCOUNTADMIN (or a role with CREATE WAREHOUSE / CREATE DATABASE /
            CREATE ROLE privileges).
================================================================================
*/

-- ============================================================
-- 0.1  Use ACCOUNTADMIN to provision foundational objects
-- ============================================================
USE ROLE ACCOUNTADMIN;


-- ============================================================
-- 0.2  Virtual Warehouse
--      One extra-small warehouse is enough for all workshop queries.
-- ============================================================
CREATE WAREHOUSE IF NOT EXISTS WORKSHOP_WH
    WAREHOUSE_SIZE   = 'X-SMALL'
    AUTO_SUSPEND     = 60          -- suspend after 60 seconds of inactivity
    AUTO_RESUME      = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Metadata-First Systems Design workshop';


-- ============================================================
-- 0.3  Database & Schemas
--      Everything lives in a single DB so teardown is simple.
-- ============================================================
CREATE DATABASE IF NOT EXISTS METADATA_WORKSHOP_DB
    COMMENT = 'Metadata-First Systems Design workshop database';

USE DATABASE METADATA_WORKSHOP_DB;

-- Schemas mirror real-world layers: raw ingestion → curated → analytics
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw / landing zone — data exactly as received from source systems';

CREATE SCHEMA IF NOT EXISTS CURATED
    COMMENT = 'Curated layer — cleaned, standardised, and tagged objects';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Analytics layer — business-facing views and aggregates';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE
    COMMENT = 'Governance objects — tags, policies, mapping tables';


-- ============================================================
-- 0.4  Roles
--      Four roles illustrate how metadata policies behave differently
--      depending on who is querying.
-- ============================================================

-- Data Engineer — can see everything, manages pipelines
CREATE ROLE IF NOT EXISTS DATA_ENGINEER
    COMMENT = 'Full access role for data engineering team';

-- Data Analyst — reads curated and analytics layers; PII is masked
CREATE ROLE IF NOT EXISTS DATA_ANALYST
    COMMENT = 'Read-only analyst role; sensitive columns are masked';

-- Data Governor — manages tags and policies
CREATE ROLE IF NOT EXISTS DATA_GOVERNOR
    COMMENT = 'Role that owns governance objects (tags, policies)';

-- Privileged Viewer — can see unmasked PII (e.g., compliance officer)
CREATE ROLE IF NOT EXISTS PRIVILEGED_VIEWER
    COMMENT = 'Elevated role that bypasses masking policies';

-- Grant roles to the current user so you can switch between them
GRANT ROLE DATA_ENGINEER    TO USER CURRENT_USER();
GRANT ROLE DATA_ANALYST     TO USER CURRENT_USER();
GRANT ROLE DATA_GOVERNOR    TO USER CURRENT_USER();
GRANT ROLE PRIVILEGED_VIEWER TO USER CURRENT_USER();

-- Role hierarchy: SYSADMIN owns everything created by workshop roles
GRANT ROLE DATA_ENGINEER     TO ROLE SYSADMIN;
GRANT ROLE DATA_ANALYST      TO ROLE SYSADMIN;
GRANT ROLE DATA_GOVERNOR     TO ROLE SYSADMIN;
GRANT ROLE PRIVILEGED_VIEWER TO ROLE SYSADMIN;


-- ============================================================
-- 0.5  Privilege Grants
-- ============================================================
GRANT USAGE  ON WAREHOUSE WORKSHOP_WH           TO ROLE DATA_ENGINEER;
GRANT USAGE  ON WAREHOUSE WORKSHOP_WH           TO ROLE DATA_ANALYST;
GRANT USAGE  ON WAREHOUSE WORKSHOP_WH           TO ROLE DATA_GOVERNOR;
GRANT USAGE  ON WAREHOUSE WORKSHOP_WH           TO ROLE PRIVILEGED_VIEWER;

GRANT USAGE  ON DATABASE  METADATA_WORKSHOP_DB  TO ROLE DATA_ENGINEER;
GRANT USAGE  ON DATABASE  METADATA_WORKSHOP_DB  TO ROLE DATA_ANALYST;
GRANT USAGE  ON DATABASE  METADATA_WORKSHOP_DB  TO ROLE DATA_GOVERNOR;
GRANT USAGE  ON DATABASE  METADATA_WORKSHOP_DB  TO ROLE PRIVILEGED_VIEWER;

-- DATA_ENGINEER gets full access to all schemas
GRANT ALL ON SCHEMA METADATA_WORKSHOP_DB.RAW        TO ROLE DATA_ENGINEER;
GRANT ALL ON SCHEMA METADATA_WORKSHOP_DB.CURATED     TO ROLE DATA_ENGINEER;
GRANT ALL ON SCHEMA METADATA_WORKSHOP_DB.ANALYTICS   TO ROLE DATA_ENGINEER;
GRANT ALL ON SCHEMA METADATA_WORKSHOP_DB.GOVERNANCE  TO ROLE DATA_ENGINEER;

-- DATA_ANALYST gets read access to curated and analytics
GRANT USAGE  ON SCHEMA METADATA_WORKSHOP_DB.CURATED   TO ROLE DATA_ANALYST;
GRANT USAGE  ON SCHEMA METADATA_WORKSHOP_DB.ANALYTICS TO ROLE DATA_ANALYST;

-- DATA_GOVERNOR owns the GOVERNANCE schema
GRANT ALL ON SCHEMA METADATA_WORKSHOP_DB.GOVERNANCE TO ROLE DATA_GOVERNOR;
GRANT USAGE ON SCHEMA METADATA_WORKSHOP_DB.CURATED  TO ROLE DATA_GOVERNOR;

-- PRIVILEGED_VIEWER gets the same read access as DATA_ANALYST
GRANT USAGE ON SCHEMA METADATA_WORKSHOP_DB.CURATED   TO ROLE PRIVILEGED_VIEWER;
GRANT USAGE ON SCHEMA METADATA_WORKSHOP_DB.ANALYTICS TO ROLE PRIVILEGED_VIEWER;


-- ============================================================
-- 0.6  Verification
-- ============================================================
USE WAREHOUSE WORKSHOP_WH;

-- Confirm schemas exist
SHOW SCHEMAS IN DATABASE METADATA_WORKSHOP_DB;

-- Confirm roles exist
SHOW ROLES LIKE '%DATA_%';
SHOW ROLES LIKE '%PRIVILEGED_%';

-- ============================================================
-- Next step: Run setup/01_sample_data.sql
-- ============================================================
