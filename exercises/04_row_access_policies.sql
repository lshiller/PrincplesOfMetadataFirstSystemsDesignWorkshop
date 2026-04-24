/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : 04_row_access_policies.sql
  Exercise: Row-Level Security via Metadata-Driven Row Access Policies

  Principle: "Policies follow metadata — row visibility is controlled by a
              mapping table, not hard-coded WHERE clauses."
  Row Access Policies (RAP) in Snowflake evaluate a boolean expression for
  each row. By pointing the policy at a GOVERNANCE mapping table, we can
  change who sees which rows without ever touching the policy SQL.

  Topics covered:
    A. Anatomy of a Row Access Policy
    B. Simple role-based row filtering (region-based example)
    C. Metadata-driven mapping table approach
    D. Applying the policy to tables
    E. Testing the policy across roles
    F. Reviewing active row access policies

  Run as  : ACCOUNTADMIN or SECURITYADMIN
  Requires: exercises/02_object_tagging.sql + setup/01_sample_data.sql
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE METADATA_WORKSHOP_DB;
USE SCHEMA   GOVERNANCE;


-- ============================================================
-- SECTION A — Anatomy of a Row Access Policy
-- ============================================================
/*
  A Row Access Policy is a schema-level object that defines a boolean
  function.  When attached to a table column, Snowflake evaluates the
  function for every row:
    - TRUE  → row is visible to the querying user
    - FALSE → row is silently filtered out

  The function receives the value of the column(s) it is bound to as
  arguments, allowing per-row decisions.

  METADATA-FIRST APPROACH:
    Store the filtering logic in a mapping table (GOVERNANCE schema),
    not in the policy SQL itself.  The policy just does a lookup.
    Changing access rules = UPDATE the mapping table, not ALTER the policy.
*/


-- ============================================================
-- SECTION B — Simple Row Access Policy (role → region)
-- ============================================================
/*
  We created GOVERNANCE.ROLE_REGION_MAPPING in setup/01_sample_data.sql.
  It maps Snowflake role names to state codes they are allowed to see.
  Rows with ALLOWED_REGION = 'ALL' grant access to every region.
*/

-- B1. Review the mapping table
SELECT * FROM GOVERNANCE.ROLE_REGION_MAPPING ORDER BY SNOWFLAKE_ROLE, ALLOWED_REGION;


-- B2. Create a Row Access Policy that consults the mapping table
CREATE OR REPLACE ROW ACCESS POLICY GOVERNANCE.RAP_CUSTOMER_REGION
    AS (customer_state_code VARCHAR) RETURNS BOOLEAN ->
    EXISTS (
        SELECT 1
        FROM GOVERNANCE.ROLE_REGION_MAPPING
        WHERE SNOWFLAKE_ROLE  = CURRENT_ROLE()
          AND (ALLOWED_REGION = customer_state_code OR ALLOWED_REGION = 'ALL')
    )
    COMMENT = 'Restricts customer rows to regions allowed for the querying role';


-- ============================================================
-- SECTION C — Department-Based Policy for Employees (HR data)
-- ============================================================
/*
  For employee data, we want:
    - DATA_ENGINEER    → sees all employees
    - PRIVILEGED_VIEWER → sees all employees
    - DATA_ANALYST     → sees only their own department's employees
    - DATA_GOVERNOR    → sees all employees (needed for governance work)

  The department mapping is stored in the governance schema so HR can
  maintain it without modifying any policy SQL.
*/

-- C1. Create department-level role mapping
CREATE OR REPLACE TABLE GOVERNANCE.ROLE_DEPARTMENT_MAPPING (
    SNOWFLAKE_ROLE  VARCHAR(100)  NOT NULL,
    ALLOWED_DEPT    VARCHAR(100)  NOT NULL,   -- department name, or 'ALL'
    NOTES           VARCHAR(500)
);

INSERT INTO GOVERNANCE.ROLE_DEPARTMENT_MAPPING VALUES
    ('DATA_ENGINEER',    'ALL',         'Engineers have full HR data access'),
    ('DATA_GOVERNOR',    'ALL',         'Governors need full access for policy work'),
    ('PRIVILEGED_VIEWER','ALL',         'Compliance sees all departments'),
    ('DATA_ANALYST',     'Analytics',   'Default analysts see Analytics dept only'),
    ('DATA_ANALYST',     'Engineering', 'Default analysts also see Engineering dept');

GRANT SELECT ON TABLE METADATA_WORKSHOP_DB.GOVERNANCE.ROLE_DEPARTMENT_MAPPING
    TO ROLE DATA_ANALYST;
GRANT SELECT ON TABLE METADATA_WORKSHOP_DB.GOVERNANCE.ROLE_DEPARTMENT_MAPPING
    TO ROLE DATA_GOVERNOR;
GRANT SELECT ON TABLE METADATA_WORKSHOP_DB.GOVERNANCE.ROLE_DEPARTMENT_MAPPING
    TO ROLE PRIVILEGED_VIEWER;
GRANT SELECT ON TABLE METADATA_WORKSHOP_DB.GOVERNANCE.ROLE_DEPARTMENT_MAPPING
    TO ROLE DATA_ENGINEER;


-- C2. Create the employee RAP
CREATE OR REPLACE ROW ACCESS POLICY GOVERNANCE.RAP_EMPLOYEE_DEPT
    AS (employee_department VARCHAR) RETURNS BOOLEAN ->
    EXISTS (
        SELECT 1
        FROM GOVERNANCE.ROLE_DEPARTMENT_MAPPING
        WHERE SNOWFLAKE_ROLE  = CURRENT_ROLE()
          AND (ALLOWED_DEPT   = employee_department OR ALLOWED_DEPT = 'ALL')
    )
    COMMENT = 'Restricts employee rows to departments permitted for the querying role';


-- ============================================================
-- SECTION D — Apply Policies to Tables
-- ============================================================

-- D1. Attach customer region policy to CURATED.CUSTOMERS
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    ADD ROW ACCESS POLICY GOVERNANCE.RAP_CUSTOMER_REGION
    ON (STATE_CODE);

-- D2. Attach employee department policy to CURATED.EMPLOYEES
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    ADD ROW ACCESS POLICY GOVERNANCE.RAP_EMPLOYEE_DEPT
    ON (DEPARTMENT);


-- ============================================================
-- SECTION E — Test the Policies
-- ============================================================

-- E1. DATA_ANALYST — should see only IL and OR customers
USE ROLE DATA_ANALYST;
USE WAREHOUSE WORKSHOP_WH;

SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, STATE_CODE, LOYALTY_TIER
FROM METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
ORDER BY STATE_CODE, CUSTOMER_ID;

/*
  EXPECTED: Only customers in IL (Alice Nguyen, Irene Dubois) and OR (Bob Martinez)
            Other states are silently filtered out.
*/


-- E2. DATA_ENGINEER — should see all customers
USE ROLE DATA_ENGINEER;

SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, STATE_CODE
FROM METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
ORDER BY STATE_CODE;

/*
  EXPECTED: All 10 customers across all states.
*/


-- E3. PRIVILEGED_VIEWER — should see all customers
USE ROLE PRIVILEGED_VIEWER;

SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, STATE_CODE
FROM METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
ORDER BY STATE_CODE;


-- E4. DATA_ANALYST — employees (Analytics + Engineering depts only)
USE ROLE DATA_ANALYST;

SELECT EMPLOYEE_ID, FIRST_NAME, LAST_NAME, DEPARTMENT, JOB_TITLE
FROM METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
ORDER BY DEPARTMENT;

/*
  EXPECTED: Employees in Analytics (Nina Osei, Lucas Ferreira) and
            Engineering (Sarah Lin, Marcus Bell, Aisha Mohammed, Leila Hassan)
  NOT VISIBLE: HR (Tom Nakamura), Compliance (Owen Wright), Governance (Priya Sharma)
*/


-- E5. DATA_GOVERNOR — should see all employees
USE ROLE DATA_GOVERNOR;

SELECT EMPLOYEE_ID, FIRST_NAME, LAST_NAME, DEPARTMENT
FROM METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
ORDER BY DEPARTMENT;


-- ============================================================
-- SECTION F — Dynamic access change WITHOUT altering the policy
-- ============================================================
/*
  KEY DEMONSTRATION: Change access by updating the mapping table,
  not by altering the policy SQL.
*/

-- F1. Temporarily grant DATA_ANALYST access to Compliance department
USE ROLE DATA_ENGINEER;

INSERT INTO GOVERNANCE.ROLE_DEPARTMENT_MAPPING
    VALUES ('DATA_ANALYST', 'Compliance', 'Temporary access for audit — remove after 2024-12-31');

-- F2. Re-run analyst query — Compliance rows now appear
USE ROLE DATA_ANALYST;
USE WAREHOUSE WORKSHOP_WH;

SELECT EMPLOYEE_ID, FIRST_NAME, LAST_NAME, DEPARTMENT
FROM METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
ORDER BY DEPARTMENT;

-- F3. Revoke the temporary access
USE ROLE DATA_ENGINEER;

DELETE FROM GOVERNANCE.ROLE_DEPARTMENT_MAPPING
WHERE SNOWFLAKE_ROLE = 'DATA_ANALYST'
  AND ALLOWED_DEPT   = 'Compliance';

-- F4. Confirm revocation
USE ROLE DATA_ANALYST;
USE WAREHOUSE WORKSHOP_WH;

SELECT EMPLOYEE_ID, FIRST_NAME, LAST_NAME, DEPARTMENT
FROM METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
ORDER BY DEPARTMENT;
-- Compliance rows should be gone again


-- ============================================================
-- SECTION G — Review Active Row Access Policies
-- ============================================================
USE ROLE ACCOUNTADMIN;

-- G1. All tables with a Row Access Policy
SELECT
    POLICY_NAME,
    REF_DATABASE_NAME,
    REF_SCHEMA_NAME,
    REF_ENTITY_NAME         AS table_name,
    REF_COLUMN_NAME         AS policy_column
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE POLICY_KIND = 'ROW_ACCESS_POLICY'
  AND REF_DATABASE_NAME = 'METADATA_WORKSHOP_DB'
ORDER BY REF_ENTITY_NAME;


-- G2. Show the policy SQL for audit purposes
DESCRIBE ROW ACCESS POLICY METADATA_WORKSHOP_DB.GOVERNANCE.RAP_CUSTOMER_REGION;
DESCRIBE ROW ACCESS POLICY METADATA_WORKSHOP_DB.GOVERNANCE.RAP_EMPLOYEE_DEPT;


-- ============================================================
-- REFLECTION QUESTIONS
-- ============================================================
/*
  1. What is the key operational advantage of storing access rules in a
     mapping table (Governance-as-Data) versus hard-coding them in the
     policy SQL?

  2. Could you implement a time-limited access grant (e.g., access only
     valid until a specific date) using this mapping table approach?
     What column(s) would you add to ROLE_DEPARTMENT_MAPPING?

  3. The RAP silently filters rows rather than raising an error.  What
     are the implications for an analyst who doesn't know about the
     policy?  How would you document this in your data catalog?

  4. Design a RAP for CURATED.ORDERS that restricts analysts to only
     seeing orders from customers in their allowed regions.
     (Hint: you'll need to JOIN to the CUSTOMERS table inside the policy.)
*/

-- ============================================================
-- Next step: Run exercises/05_data_classification.sql
-- ============================================================
