/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : 03_dynamic_data_masking.sql
  Exercise: Tag-driven Dynamic Data Masking Policies

  Principle: "Policies follow tags — security rules bind to tags, not columns."
  Dynamic Data Masking (DDM) lets us define masking behaviour once and attach
  it to any column carrying the right tag, regardless of table or column name.

  Topics covered:
    A. Creating masking policies for each PII category
    B. Attaching policies to columns via TAG (tag-based masking)
    C. Testing masking behaviour across roles
    D. Conditional unmasking — PRIVILEGED_VIEWER bypasses masks
    E. Reviewing active masking policies

  Run as  : ACCOUNTADMIN or SECURITYADMIN (to CREATE MASKING POLICY and
            apply conditional masking), then switch roles to test.
  Requires: exercises/02_object_tagging.sql
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE METADATA_WORKSHOP_DB;
USE SCHEMA   GOVERNANCE;


-- ============================================================
-- SECTION A — Create Masking Policies
-- ============================================================
/*
  Each policy inspects the CURRENT_ROLE() at query time.
  - PRIVILEGED_VIEWER and DATA_ENGINEER see plaintext.
  - All other roles see masked values.

  Key design decision: one policy per PII category.
  This makes it trivial to add new tables — just tag the column and
  the right policy is automatically applied.
*/

-- A1. Email masking — show domain only (alice@example.com → ****@example.com)
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_EMAIL
    AS (col_value VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('PRIVILEGED_VIEWER', 'DATA_ENGINEER', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE CONCAT('****@', SPLIT_PART(col_value, '@', 2))
    END
    COMMENT = 'Masks the local part of an email address for non-privileged roles';


-- A2. Phone masking — show last 4 digits only (555-0101 → ***-0101)
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_PHONE
    AS (col_value VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('PRIVILEGED_VIEWER', 'DATA_ENGINEER', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE CONCAT('***-', RIGHT(REGEXP_REPLACE(col_value, '[^0-9]', ''), 4))
    END
    COMMENT = 'Shows only the last 4 digits of a phone number';


-- A3. SSN masking — full redaction (123-45-6789 → ***-**-****)
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_SSN
    AS (col_value VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('PRIVILEGED_VIEWER', 'DATA_ENGINEER', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE '***-**-****'
    END
    COMMENT = 'Fully redacts Social Security Numbers';


-- A4. Date of birth masking — show birth year only (1985-03-12 → 1985-**-**)
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_DATE_OF_BIRTH
    AS (col_value DATE) RETURNS DATE ->
    CASE
        WHEN CURRENT_ROLE() IN ('PRIVILEGED_VIEWER', 'DATA_ENGINEER', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE DATE_FROM_PARTS(YEAR(col_value), 1, 1)   -- truncate to Jan 1 of birth year
    END
    COMMENT = 'Truncates date of birth to the first day of the birth year';


-- A5. Address masking — nullify for non-privileged roles
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_ADDRESS
    AS (col_value VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('PRIVILEGED_VIEWER', 'DATA_ENGINEER', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE '*** REDACTED ***'
    END
    COMMENT = 'Redacts street address for non-privileged roles';


-- A6. Salary masking — show range band instead of exact figure
--     (e.g., 120,000 → '100K–149K')
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_SALARY
    AS (col_value NUMBER) RETURNS NUMBER ->
    CASE
        WHEN CURRENT_ROLE() IN ('PRIVILEGED_VIEWER', 'DATA_GOVERNOR', 'DATA_ENGINEER', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE NULL          -- analysts cannot see salary at all
    END
    COMMENT = 'Returns NULL for non-privileged roles; exact value for HR/privileged';


-- A7. Payment card masking — last 4 already stored; fully redact for non-privileged
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_PAYMENT_CARD
    AS (col_value VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('PRIVILEGED_VIEWER', 'DATA_ENGINEER', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE '****'
    END
    COMMENT = 'Masks payment card data; only privileged roles see last-4 digits';


-- A8. Name masking — show initials only (Alice Nguyen → A. N.)
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_NAME
    AS (col_value VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('PRIVILEGED_VIEWER', 'DATA_ENGINEER', 'DATA_GOVERNOR', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE CONCAT(LEFT(col_value, 1), '.')
    END
    COMMENT = 'Shows only the first initial for DATA_ANALYST role';


-- Verify all policies were created
SHOW MASKING POLICIES IN SCHEMA METADATA_WORKSHOP_DB.GOVERNANCE;


-- ============================================================
-- SECTION B — Attach Masking Policies to Tags (Tag-Based Masking)
-- ============================================================
/*
  TAG-BASED MASKING is the key differentiator of a Metadata-First approach.
  Instead of ALTER TABLE ... MODIFY COLUMN ... SET MASKING POLICY (column-by-
  column), we attach one masking policy to each TAG VALUE.

  Snowflake then automatically applies the policy to every column carrying
  that tag — including future columns added to any table.
*/

-- B1. Attach masking policies to the PII_CATEGORY tag values
ALTER TAG GOVERNANCE.PII_CATEGORY
    SET MASKING POLICY GOVERNANCE.MASK_EMAIL   USING (TAG_VALUE)
    FOR COLUMN TYPE VARCHAR
    WHEN TAG_VALUE = 'EMAIL';

/*
  NOTE: As of 2024, Snowflake supports one masking policy per tag per data type.
  If you need different masks for different PII categories (EMAIL vs PHONE),
  the recommended approach is either:
    a) Create one tag per category (TAG_EMAIL, TAG_PHONE, etc.) and bind one
       policy to each tag.
    b) Use a conditional masking policy on the PII_CATEGORY tag that inspects
       the TAG_VALUE.

  For this workshop we use approach (a) combined with approach (b) to
  illustrate both patterns.  In production, the approach you choose depends
  on whether your masking logic varies significantly between categories.
*/

-- For the workshop, attach policies directly to the columns tagged
-- (column-level binding — the most universally supported method):
USE ROLE ACCOUNTADMIN;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN EMAIL           SET MASKING POLICY GOVERNANCE.MASK_EMAIL;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN PHONE           SET MASKING POLICY GOVERNANCE.MASK_PHONE;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN SSN             SET MASKING POLICY GOVERNANCE.MASK_SSN;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN DATE_OF_BIRTH   SET MASKING POLICY GOVERNANCE.MASK_DATE_OF_BIRTH;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN STREET_ADDRESS  SET MASKING POLICY GOVERNANCE.MASK_ADDRESS;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN FIRST_NAME      SET MASKING POLICY GOVERNANCE.MASK_NAME;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN LAST_NAME       SET MASKING POLICY GOVERNANCE.MASK_NAME;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN EMAIL           SET MASKING POLICY GOVERNANCE.MASK_EMAIL;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN PHONE           SET MASKING POLICY GOVERNANCE.MASK_PHONE;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN SSN             SET MASKING POLICY GOVERNANCE.MASK_SSN;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN DATE_OF_BIRTH   SET MASKING POLICY GOVERNANCE.MASK_DATE_OF_BIRTH;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN ANNUAL_SALARY   SET MASKING POLICY GOVERNANCE.MASK_SALARY;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN FIRST_NAME      SET MASKING POLICY GOVERNANCE.MASK_NAME;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN LAST_NAME       SET MASKING POLICY GOVERNANCE.MASK_NAME;

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.ORDERS
    MODIFY COLUMN CREDIT_CARD_LAST4 SET MASKING POLICY GOVERNANCE.MASK_PAYMENT_CARD;


-- ============================================================
-- SECTION C — Test Masking Behaviour Across Roles
-- ============================================================

-- C1. Query as DATA_ANALYST — should see masked values
USE ROLE DATA_ANALYST;
USE WAREHOUSE WORKSHOP_WH;

SELECT
    CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME,
    EMAIL,
    PHONE,
    DATE_OF_BIRTH,
    SSN,
    STREET_ADDRESS
FROM METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
LIMIT 5;

/*
  EXPECTED OUTPUT (DATA_ANALYST):
    FIRST_NAME    → A. (initial only)
    LAST_NAME     → N. (initial only)
    EMAIL         → ****@example.com
    PHONE         → ***-0101
    DATE_OF_BIRTH → 1985-01-01 (year only)
    SSN           → ***-**-****
    STREET_ADDRESS → *** REDACTED ***
*/


-- C2. Query as DATA_ENGINEER — should see plain text
USE ROLE DATA_ENGINEER;

SELECT
    CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME,
    EMAIL,
    PHONE,
    DATE_OF_BIRTH,
    SSN,
    STREET_ADDRESS
FROM METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
LIMIT 5;

/*
  EXPECTED OUTPUT (DATA_ENGINEER):
    All columns show the original unmasked values.
*/


-- C3. Query as PRIVILEGED_VIEWER — should see plain text
USE ROLE PRIVILEGED_VIEWER;

SELECT
    CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME,
    EMAIL,
    PHONE,
    DATE_OF_BIRTH,
    SSN,
    STREET_ADDRESS
FROM METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
LIMIT 5;


-- C4. Verify salary masking on EMPLOYEES
USE ROLE DATA_ANALYST;

SELECT EMPLOYEE_ID, FIRST_NAME, LAST_NAME, DEPARTMENT, JOB_TITLE, ANNUAL_SALARY
FROM METADATA_WORKSHOP_DB.CURATED.EMPLOYEES;
-- ANNUAL_SALARY should be NULL for DATA_ANALYST

USE ROLE DATA_GOVERNOR;

SELECT EMPLOYEE_ID, FIRST_NAME, LAST_NAME, DEPARTMENT, JOB_TITLE, ANNUAL_SALARY
FROM METADATA_WORKSHOP_DB.CURATED.EMPLOYEES;
-- DATA_GOVERNOR can see salaries (included in MASK_SALARY allowed roles)


-- ============================================================
-- SECTION D — Review Active Masking Policies (ACCOUNT_USAGE)
-- ============================================================
USE ROLE ACCOUNTADMIN;

-- D1. All columns with an active masking policy
SELECT
    POLICY_NAME,
    POLICY_KIND,
    REF_DATABASE_NAME,
    REF_SCHEMA_NAME,
    REF_ENTITY_NAME                     AS table_name,
    REF_COLUMN_NAME                     AS column_name
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE POLICY_KIND = 'MASKING_POLICY'
  AND REF_DATABASE_NAME = 'METADATA_WORKSHOP_DB'
ORDER BY REF_ENTITY_NAME, REF_COLUMN_NAME;


-- D2. Cross-reference: tagged columns vs columns with masking policies
--     Find tagged columns that do NOT yet have a masking policy (coverage gap)
WITH tagged_columns AS (
    SELECT 'CURATED.CUSTOMERS' AS qualified_table, COLUMN_NAME
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'))
    WHERE TAG_NAME = 'SENSITIVITY' AND TAG_VALUE IN ('RESTRICTED', 'CONFIDENTIAL')
    UNION ALL
    SELECT 'CURATED.EMPLOYEES', COLUMN_NAME
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.EMPLOYEES', 'TABLE'))
    WHERE TAG_NAME = 'SENSITIVITY' AND TAG_VALUE IN ('RESTRICTED', 'CONFIDENTIAL')
    UNION ALL
    SELECT 'CURATED.ORDERS', COLUMN_NAME
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.ORDERS', 'TABLE'))
    WHERE TAG_NAME = 'SENSITIVITY' AND TAG_VALUE IN ('RESTRICTED', 'CONFIDENTIAL')
),
masked_columns AS (
    SELECT
        CONCAT(REF_SCHEMA_NAME, '.', REF_ENTITY_NAME)  AS qualified_table,
        REF_COLUMN_NAME                                AS column_name
    FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
    WHERE POLICY_KIND = 'MASKING_POLICY'
      AND REF_DATABASE_NAME = 'METADATA_WORKSHOP_DB'
)
SELECT
    tc.qualified_table,
    tc.COLUMN_NAME,
    CASE WHEN mc.column_name IS NULL THEN 'MISSING MASKING POLICY' ELSE 'COVERED' END AS status
FROM tagged_columns tc
LEFT JOIN masked_columns mc
  ON tc.qualified_table = mc.qualified_table
 AND tc.COLUMN_NAME     = mc.column_name
ORDER BY status DESC, tc.qualified_table, tc.COLUMN_NAME;


-- ============================================================
-- REFLECTION QUESTIONS
-- ============================================================
/*
  1. What is the operational advantage of tag-based masking over
     column-by-column masking policy assignment?

  2. A new engineer adds a MOBILE_PHONE column to CURATED.CUSTOMERS but
     forgets to apply a masking policy.  Using what you learned in this
     exercise, how would you detect and remediate this gap automatically?

  3. The MASK_SALARY policy returns NULL for DATA_ANALYST.  Is returning
     NULL the right choice?  What are the trade-offs versus returning a
     range band (e.g., '100K–149K')?

  4. How would you modify MASK_EMAIL to also allow users whose Snowflake
     user email domain matches the data domain (e.g., HR staff seeing
     employee emails from @northstar.com)?
*/

-- ============================================================
-- Next step: Run exercises/04_row_access_policies.sql
-- ============================================================
