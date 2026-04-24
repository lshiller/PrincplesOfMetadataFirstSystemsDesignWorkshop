/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : teardown.sql
  Purpose : Remove ALL objects created during the workshop.
            Run this script when the workshop is complete.

  WARNING : This script is DESTRUCTIVE. It drops the entire workshop
            database, warehouse, and roles.
            Do NOT run this on a shared Snowflake account without
            confirming that no other users rely on these objects.

  Run as  : ACCOUNTADMIN
================================================================================
*/

USE ROLE ACCOUNTADMIN;


-- ============================================================
-- 1.  Policies must be detached before tables can be dropped
--     (Snowflake prevents dropping tables with active policies)
-- ============================================================

USE WAREHOUSE WORKSHOP_WH;
USE DATABASE METADATA_WORKSHOP_DB;

-- Detach masking policies
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN EMAIL           UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN PHONE           UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN SSN             UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN DATE_OF_BIRTH   UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN STREET_ADDRESS  UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN FIRST_NAME      UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN LAST_NAME       UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN LOYALTY_POINTS  UNSET MASKING POLICY;

ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN EMAIL           UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN PHONE           UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN SSN             UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN DATE_OF_BIRTH   UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN ANNUAL_SALARY   UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN FIRST_NAME      UNSET MASKING POLICY;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN LAST_NAME       UNSET MASKING POLICY;

ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.ORDERS
    MODIFY COLUMN CREDIT_CARD_LAST4 UNSET MASKING POLICY;

-- Detach row access policies
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    DROP ROW ACCESS POLICY METADATA_WORKSHOP_DB.GOVERNANCE.RAP_CUSTOMER_REGION;
ALTER TABLE IF EXISTS METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    DROP ROW ACCESS POLICY METADATA_WORKSHOP_DB.GOVERNANCE.RAP_EMPLOYEE_DEPT;


-- ============================================================
-- 2.  Drop the entire workshop database (cascades to all objects)
-- ============================================================
DROP DATABASE IF EXISTS METADATA_WORKSHOP_DB;


-- ============================================================
-- 3.  Drop the workshop warehouse
-- ============================================================
DROP WAREHOUSE IF EXISTS WORKSHOP_WH;


-- ============================================================
-- 4.  Drop workshop roles
--     Revoke from SYSADMIN first to avoid "role in use" errors
-- ============================================================
REVOKE ROLE DATA_ENGINEER     FROM ROLE SYSADMIN;
REVOKE ROLE DATA_ANALYST      FROM ROLE SYSADMIN;
REVOKE ROLE DATA_GOVERNOR     FROM ROLE SYSADMIN;
REVOKE ROLE PRIVILEGED_VIEWER FROM ROLE SYSADMIN;

DROP ROLE IF EXISTS DATA_ENGINEER;
DROP ROLE IF EXISTS DATA_ANALYST;
DROP ROLE IF EXISTS DATA_GOVERNOR;
DROP ROLE IF EXISTS PRIVILEGED_VIEWER;


-- ============================================================
-- 5.  Verify all workshop objects are gone
-- ============================================================
SHOW DATABASES      LIKE 'METADATA_WORKSHOP%';
SHOW WAREHOUSES     LIKE 'WORKSHOP%';
SHOW ROLES          LIKE 'DATA_%';
SHOW ROLES          LIKE 'PRIVILEGED_%';

-- All four SHOW commands should return empty result sets.
-- If any objects remain, drop them manually.
