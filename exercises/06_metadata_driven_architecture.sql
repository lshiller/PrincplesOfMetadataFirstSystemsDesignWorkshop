/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : 06_metadata_driven_architecture.sql
  Exercise: Metadata-Driven Architecture Patterns

  Principle: "Governance as code — metadata rules live in version-controlled
              SQL alongside the data model."
  In this capstone exercise we tie all previous concepts together and build
  reusable patterns that let metadata DRIVE the system rather than document it
  after the fact.

  Topics covered:
    A. Metadata-driven analytics views (auto-masking applied)
    B. Governance summary dashboards
    C. Column lineage via ACCESS_HISTORY
    D. Generating DDL documentation from metadata
    E. Change detection — alerting when untagged objects appear
    F. End-to-end: adding a NEW sensitive column the Metadata-First way

  Run as  : DATA_ENGINEER (most sections), ACCOUNTADMIN (for ACCOUNT_USAGE)
  Requires: All previous exercises
================================================================================
*/

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE METADATA_WORKSHOP_DB;
USE SCHEMA   ANALYTICS;


-- ============================================================
-- SECTION A — Metadata-Driven Analytics Views
-- ============================================================
/*
  Analytics views in the ANALYTICS schema expose data from CURATED.
  Because CURATED already has masking policies and row access policies
  attached, the views automatically inherit them — zero extra security code.

  This is the "policies follow tags, views follow policies" pattern.
*/

-- A1. Customer analytics view
CREATE OR REPLACE VIEW ANALYTICS.V_CUSTOMERS AS
    SELECT
        CUSTOMER_ID,
        FIRST_NAME,
        LAST_NAME,
        EMAIL,
        PHONE,
        DATE_OF_BIRTH,
        CITY,
        STATE_CODE,
        ZIP_CODE,
        COUNTRY_CODE,
        LOYALTY_TIER,
        CREATED_AT
    FROM METADATA_WORKSHOP_DB.CURATED.CUSTOMERS;

-- A2. Employee directory view (ACTIVE employees only — business logic in the view)
CREATE OR REPLACE VIEW ANALYTICS.V_EMPLOYEE_DIRECTORY AS
    SELECT
        EMPLOYEE_ID,
        FIRST_NAME,
        LAST_NAME,
        EMAIL,
        DEPARTMENT,
        JOB_TITLE,
        HIRE_DATE,
        ACTIVE
    FROM METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    WHERE ACTIVE = TRUE;

-- A3. Order summary view (aggregated — no PII exposed at row level)
CREATE OR REPLACE VIEW ANALYTICS.V_ORDER_SUMMARY AS
    SELECT
        o.ORDER_ID,
        o.CUSTOMER_ID,
        o.ORDER_DATE,
        o.STATUS,
        o.TOTAL_AMOUNT,
        c.CITY          AS customer_city,
        c.STATE_CODE    AS customer_state,
        c.LOYALTY_TIER
    FROM METADATA_WORKSHOP_DB.CURATED.ORDERS    o
    JOIN METADATA_WORKSHOP_DB.CURATED.CUSTOMERS c
      ON o.CUSTOMER_ID = c.CUSTOMER_ID;

-- Grant access
GRANT SELECT ON ALL VIEWS IN SCHEMA METADATA_WORKSHOP_DB.ANALYTICS TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA METADATA_WORKSHOP_DB.ANALYTICS TO ROLE PRIVILEGED_VIEWER;

-- A4. Test: DATA_ANALYST sees masked values even through the view
USE ROLE DATA_ANALYST;
USE WAREHOUSE WORKSHOP_WH;

SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, STATE_CODE
FROM ANALYTICS.V_CUSTOMERS
LIMIT 5;
-- Masking and row filtering are enforced transparently


-- ============================================================
-- SECTION B — Governance Summary Dashboards
-- ============================================================
USE ROLE DATA_ENGINEER;
USE SCHEMA GOVERNANCE;

-- B1. "State of the Data" summary — tags, policies, and classification at a glance
CREATE OR REPLACE VIEW GOVERNANCE.V_GOVERNANCE_SUMMARY AS
WITH tables AS (
    SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, ROW_COUNT, BYTES
    FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA', 'GOVERNANCE')
      AND TABLE_TYPE = 'BASE TABLE'
),
sensitivity_tags AS (
    SELECT 'CURATED.CUSTOMERS' AS q_table, TAG_VALUE AS sensitivity
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'))
    WHERE TAG_NAME = 'SENSITIVITY' AND COLUMN_NAME IS NULL
    UNION ALL
    SELECT 'CURATED.EMPLOYEES', TAG_VALUE
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.EMPLOYEES', 'TABLE'))
    WHERE TAG_NAME = 'SENSITIVITY' AND COLUMN_NAME IS NULL
    UNION ALL
    SELECT 'CURATED.ORDERS', TAG_VALUE
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.ORDERS', 'TABLE'))
    WHERE TAG_NAME = 'SENSITIVITY' AND COLUMN_NAME IS NULL
    UNION ALL
    SELECT 'CURATED.PRODUCTS', TAG_VALUE
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.PRODUCTS', 'TABLE'))
    WHERE TAG_NAME = 'SENSITIVITY' AND COLUMN_NAME IS NULL
    UNION ALL
    SELECT 'CURATED.ORDER_ITEMS', TAG_VALUE
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.ORDER_ITEMS', 'TABLE'))
    WHERE TAG_NAME = 'SENSITIVITY' AND COLUMN_NAME IS NULL
)
SELECT
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    t.ROW_COUNT,
    ROUND(t.BYTES / POWER(1024, 2), 3)  AS size_mb,
    st.sensitivity                      AS table_sensitivity
FROM tables t
LEFT JOIN sensitivity_tags st
  ON CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) = st.q_table
ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME;

SELECT * FROM GOVERNANCE.V_GOVERNANCE_SUMMARY;


-- B2. PII exposure report — which columns carry PII and what is their masking status?
CREATE OR REPLACE VIEW GOVERNANCE.V_PII_EXPOSURE_REPORT AS
WITH pii_cols AS (
    SELECT 'CUSTOMERS' AS tbl, COLUMN_NAME, TAG_VALUE AS pii_category
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'))
    WHERE TAG_NAME = 'PII_CATEGORY' AND TAG_VALUE != 'NONE'
    UNION ALL
    SELECT 'EMPLOYEES', COLUMN_NAME, TAG_VALUE
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.EMPLOYEES', 'TABLE'))
    WHERE TAG_NAME = 'PII_CATEGORY' AND TAG_VALUE != 'NONE'
    UNION ALL
    SELECT 'ORDERS', COLUMN_NAME, TAG_VALUE
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.ORDERS', 'TABLE'))
    WHERE TAG_NAME = 'PII_CATEGORY' AND TAG_VALUE != 'NONE'
)
SELECT
    tbl                                 AS table_name,
    COLUMN_NAME,
    pii_category,
    'See POLICY_REFERENCES in ACCOUNT_USAGE' AS masking_note
FROM pii_cols
ORDER BY table_name, pii_category, COLUMN_NAME;

SELECT * FROM GOVERNANCE.V_PII_EXPOSURE_REPORT;


-- ============================================================
-- SECTION C — Column Lineage via ACCESS_HISTORY
-- ============================================================
/*
  Snowflake's ACCESS_HISTORY table in ACCOUNT_USAGE records which columns
  were accessed by each query, enabling column-level lineage.
  This is invaluable for impact analysis: "If I change column X, who is affected?"
*/
USE ROLE ACCOUNTADMIN;

-- C1. Which queries accessed the SSN column in the last 30 days?
SELECT
    qh.QUERY_ID,
    qh.QUERY_TEXT,
    qh.USER_NAME,
    qh.ROLE_NAME,
    qh.START_TIME,
    qh.QUERY_TYPE
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY   qh
JOIN SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY  ah
  ON qh.QUERY_ID = ah.QUERY_ID
JOIN LATERAL FLATTEN(INPUT => ah.COLUMNS_ACCESSED)  AS f
WHERE f.value:columnName::STRING         = 'SSN'
  AND f.value:objectName::STRING ILIKE '%CURATED%'
  AND qh.START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY qh.START_TIME DESC
LIMIT 20;


-- C2. Downstream impact analysis — find all objects that read from CURATED.CUSTOMERS
SELECT DISTINCT
    oh.VALUE:objectName::STRING     AS downstream_object
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah
JOIN LATERAL FLATTEN(INPUT => ah.OBJECTS_MODIFIED) AS oh
JOIN LATERAL FLATTEN(INPUT => ah.BASE_OBJECTS_ACCESSED) AS bh
WHERE bh.VALUE:objectName::STRING ILIKE '%CURATED.CUSTOMERS%'
  AND ah.QUERY_START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY 1;


-- ============================================================
-- SECTION D — Generating Documentation from Metadata
-- ============================================================
/*
  Instead of maintaining hand-written data dictionaries, generate them
  from INFORMATION_SCHEMA + tag metadata.  This ensures docs are always
  in sync with the actual schema.
*/
USE ROLE DATA_ENGINEER;
USE SCHEMA GOVERNANCE;

-- D1. Auto-generate a data dictionary for all CURATED tables
SELECT
    c.TABLE_NAME                        AS "Table",
    c.ORDINAL_POSITION                  AS "#",
    c.COLUMN_NAME                       AS "Column",
    c.DATA_TYPE                         AS "Type",
    c.IS_NULLABLE                       AS "Nullable",
    '' AS "PII Category",               -- populated below in real usage
    '' AS "Sensitivity"                 -- populated below in real usage
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'CURATED'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;

/*
  In a production pipeline you would:
    1. Run this query
    2. JOIN to the TAG_REFERENCES results from exercise 02
    3. Export to a documentation platform (Confluence, Notion, etc.)
       or a data catalog (Alation, Collibra, Atlan)

  Because the source of truth is Snowflake metadata, the docs rebuild
  themselves every time a new column or tag is added.
*/


-- ============================================================
-- SECTION E — Change Detection: Alert When Untagged Objects Appear
-- ============================================================
/*
  Use a Snowflake Dynamic Table (or a scheduled Task + Stream) to
  continuously monitor for columns that lack required tags.

  Here we implement the simpler Task-based approach.
*/

-- E1. Stored procedure that scans for untagged CURATED columns
CREATE OR REPLACE PROCEDURE GOVERNANCE.SP_CHECK_UNTAGGED_COLUMNS()
    RETURNS TABLE (table_name VARCHAR, column_name VARCHAR, issue VARCHAR)
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
$$
DECLARE
    result RESULTSET DEFAULT (
        SELECT
            c.TABLE_NAME,
            c.COLUMN_NAME,
            'Missing SENSITIVITY tag' AS issue
        FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.COLUMNS c
        WHERE c.TABLE_SCHEMA = 'CURATED'
          AND NOT EXISTS (
            SELECT 1
            FROM TABLE(
                METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
                    CONCAT('METADATA_WORKSHOP_DB.CURATED.', c.TABLE_NAME), 'TABLE'
                )
            )
            WHERE TAG_NAME = 'SENSITIVITY'
              AND (COLUMN_NAME = c.COLUMN_NAME OR COLUMN_NAME IS NULL)
          )
        ORDER BY c.TABLE_NAME, c.COLUMN_NAME
    );
BEGIN
    RETURN TABLE(result);
END;
$$;

-- E2. Run the check
CALL GOVERNANCE.SP_CHECK_UNTAGGED_COLUMNS();


-- ============================================================
-- SECTION F — End-to-End: Adding a New Sensitive Column
--             THE METADATA-FIRST WAY
-- ============================================================
/*
  SCENARIO: The business wants to add a LOYALTY_POINTS column to
  CURATED.CUSTOMERS that stores the customer's reward points balance.
  This is not PII, but it is CONFIDENTIAL business data.

  The Metadata-First workflow:
    Step 1 — Add the column (DDL)
    Step 2 — Apply tags (metadata)
    Step 3 — Masking policy is inherited via the table-level SENSITIVITY tag
    Step 4 — Verify in governance views

  Notice: Steps 2-4 happen BEFORE any data is loaded — metadata leads.
*/

-- F1. Step 1: Add the column
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    ADD COLUMN LOYALTY_POINTS NUMBER DEFAULT 0
    COMMENT = 'Customer loyalty reward points balance';

-- F2. Step 2: Tag it immediately
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN LOYALTY_POINTS
        SET TAG GOVERNANCE.SENSITIVITY    = 'CONFIDENTIAL',
                GOVERNANCE.PII_CATEGORY   = 'NONE';

-- F3. Step 3: Create a specific masking policy for loyalty points
--     (CONFIDENTIAL but not PII — show 0 for non-analysts, exact value for analysts+)
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE MASKING POLICY METADATA_WORKSHOP_DB.GOVERNANCE.MASK_LOYALTY_POINTS
    AS (col_value NUMBER) RETURNS NUMBER ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ANALYST', 'PRIVILEGED_VIEWER', 'DATA_ENGINEER',
                                 'DATA_GOVERNOR', 'ACCOUNTADMIN', 'SYSADMIN')
            THEN col_value
        ELSE 0
    END
    COMMENT = 'CONFIDENTIAL — shows 0 to anonymous/unauthenticated access; real value to authenticated roles';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN LOYALTY_POINTS
        SET MASKING POLICY METADATA_WORKSHOP_DB.GOVERNANCE.MASK_LOYALTY_POINTS;

-- F4. Step 4: Verify in governance views
USE ROLE DATA_ENGINEER;

SELECT *
FROM GOVERNANCE.V_GOVERNANCE_SUMMARY
WHERE TABLE_NAME = 'CUSTOMERS';

SELECT *
FROM TABLE(
    METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
        'METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'
    )
)
WHERE COLUMN_NAME = 'LOYALTY_POINTS';

-- F5. Step 5: Load some data now that the metadata guardrails are in place
USE ROLE DATA_ENGINEER;

UPDATE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
SET LOYALTY_POINTS = CASE LOYALTY_TIER
    WHEN 'BRONZE'   THEN  250
    WHEN 'SILVER'   THEN  750
    WHEN 'GOLD'     THEN 2500
    WHEN 'PLATINUM' THEN 7500
    ELSE 0
END;

-- F6. Verify as DATA_ANALYST (should see real points — CONFIDENTIAL policy allows analysts)
USE ROLE DATA_ANALYST;
USE WAREHOUSE WORKSHOP_WH;

SELECT CUSTOMER_ID, LOYALTY_TIER, LOYALTY_POINTS
FROM ANALYTICS.V_CUSTOMERS
ORDER BY LOYALTY_POINTS DESC;


-- ============================================================
-- REFLECTION QUESTIONS
-- ============================================================
/*
  1. In Section A we created ANALYTICS views that inherit masking and row
     access policies automatically.  What is the performance implication
     of having policies evaluated at every query?  How does Snowflake
     mitigate this?

  2. The SP_CHECK_UNTAGGED_COLUMNS procedure identifies coverage gaps.
     How would you integrate this into a CI/CD pipeline so that a pull
     request cannot add an untagged column?

  3. In Section F we followed the Metadata-First workflow: metadata BEFORE
     data.  What organisational processes would you put in place to ensure
     engineers follow this workflow consistently?

  4. How would you build a complete data catalog using only Snowflake
     metadata (no external tools)?  What would be the limitations compared
     to a dedicated catalog product?
*/

-- ============================================================
-- Workshop complete! Run teardown/teardown.sql when finished.
-- ============================================================
