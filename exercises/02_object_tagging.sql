/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : 02_object_tagging.sql
  Exercise: Creating and applying Snowflake Object Tags

  Principle: "Tag everything — attach business-context tags at creation time."
  Object Tags turn informal documentation into machine-readable metadata that
  policies, governance reports, and automated processes can act upon.

  Topics covered:
    A. Creating Tag objects in the GOVERNANCE schema
    B. Applying tags to databases, schemas, tables, and columns
    C. Querying applied tags via TAG_REFERENCES
    D. Propagating tags: schema-level vs column-level inheritance
    E. Building a tag-based data inventory view

  Run as  : DATA_GOVERNOR (owns tags) + DATA_ENGINEER (applies to tables)
  Requires: setup/01_sample_data.sql
================================================================================
*/

USE ROLE DATA_GOVERNOR;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE METADATA_WORKSHOP_DB;
USE SCHEMA   GOVERNANCE;


-- ============================================================
-- SECTION A — Create Tag Objects
-- ============================================================
/*
  Tags in Snowflake are first-class schema objects.
  Each tag can have an optional set of allowed values to enforce
  controlled vocabulary — a key principle of metadata governance.
*/

-- A1. Data sensitivity classification tag
CREATE OR REPLACE TAG GOVERNANCE.SENSITIVITY
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    COMMENT = 'Data sensitivity level following the NorthStar data classification policy';

-- A2. PII category — what kind of personal information this column contains
CREATE OR REPLACE TAG GOVERNANCE.PII_CATEGORY
    ALLOWED_VALUES 'NAME', 'EMAIL', 'PHONE', 'SSN', 'DATE_OF_BIRTH',
                   'ADDRESS', 'PAYMENT_CARD', 'SALARY', 'NONE'
    COMMENT = 'Type of Personal Identifiable Information stored in this column';

-- A3. Data domain — which business domain owns this object
CREATE OR REPLACE TAG GOVERNANCE.DATA_DOMAIN
    ALLOWED_VALUES 'RETAIL', 'HR', 'FINANCE', 'SHARED'
    COMMENT = 'Business domain that owns this data asset';

-- A4. Retention period — how long data must/may be retained
CREATE OR REPLACE TAG GOVERNANCE.RETENTION_PERIOD
    ALLOWED_VALUES '1_YEAR', '3_YEARS', '7_YEARS', 'INDEFINITE'
    COMMENT = 'Required data retention period per legal/compliance policy';

-- A5. Source system — where does this data originate?
CREATE OR REPLACE TAG GOVERNANCE.SOURCE_SYSTEM
    COMMENT = 'Name of the source system that produces this data (free text)';

-- Verify tags were created
SHOW TAGS IN SCHEMA METADATA_WORKSHOP_DB.GOVERNANCE;


-- ============================================================
-- SECTION B — Apply Tags to Workshop Objects
-- ============================================================

-- ── B1.  Tag schemas ─────────────────────────────────────────
USE ROLE DATA_ENGINEER;

ALTER SCHEMA METADATA_WORKSHOP_DB.RAW      SET TAG GOVERNANCE.DATA_DOMAIN = 'SHARED';
ALTER SCHEMA METADATA_WORKSHOP_DB.CURATED  SET TAG GOVERNANCE.DATA_DOMAIN = 'SHARED';
ALTER SCHEMA METADATA_WORKSHOP_DB.ANALYTICS SET TAG GOVERNANCE.DATA_DOMAIN = 'SHARED';

-- ── B2.  Tag tables ──────────────────────────────────────────

-- CUSTOMERS table
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    SET TAG
        GOVERNANCE.SENSITIVITY     = 'RESTRICTED',
        GOVERNANCE.DATA_DOMAIN     = 'RETAIL',
        GOVERNANCE.RETENTION_PERIOD = '3_YEARS',
        GOVERNANCE.SOURCE_SYSTEM   = 'CRM_System_v2';

-- EMPLOYEES table
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    SET TAG
        GOVERNANCE.SENSITIVITY     = 'RESTRICTED',
        GOVERNANCE.DATA_DOMAIN     = 'HR',
        GOVERNANCE.RETENTION_PERIOD = '7_YEARS',
        GOVERNANCE.SOURCE_SYSTEM   = 'HRIS_Workday';

-- ORDERS table
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.ORDERS
    SET TAG
        GOVERNANCE.SENSITIVITY     = 'CONFIDENTIAL',
        GOVERNANCE.DATA_DOMAIN     = 'RETAIL',
        GOVERNANCE.RETENTION_PERIOD = '7_YEARS',
        GOVERNANCE.SOURCE_SYSTEM   = 'OMS_v3';

-- PRODUCTS table
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.PRODUCTS
    SET TAG
        GOVERNANCE.SENSITIVITY     = 'INTERNAL',
        GOVERNANCE.DATA_DOMAIN     = 'RETAIL',
        GOVERNANCE.RETENTION_PERIOD = '3_YEARS',
        GOVERNANCE.SOURCE_SYSTEM   = 'PIM_System';

-- ORDER_ITEMS table
ALTER TABLE METADATA_WORKSHOP_DB.CURATED.ORDER_ITEMS
    SET TAG
        GOVERNANCE.SENSITIVITY     = 'CONFIDENTIAL',
        GOVERNANCE.DATA_DOMAIN     = 'RETAIL',
        GOVERNANCE.RETENTION_PERIOD = '7_YEARS',
        GOVERNANCE.SOURCE_SYSTEM   = 'OMS_v3';


-- ── B3.  Tag sensitive columns in CURATED.CUSTOMERS ──────────

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN FIRST_NAME
        SET TAG GOVERNANCE.SENSITIVITY = 'CONFIDENTIAL',
                GOVERNANCE.PII_CATEGORY = 'NAME';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN LAST_NAME
        SET TAG GOVERNANCE.SENSITIVITY = 'CONFIDENTIAL',
                GOVERNANCE.PII_CATEGORY = 'NAME';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN EMAIL
        SET TAG GOVERNANCE.SENSITIVITY = 'RESTRICTED',
                GOVERNANCE.PII_CATEGORY = 'EMAIL';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN PHONE
        SET TAG GOVERNANCE.SENSITIVITY = 'CONFIDENTIAL',
                GOVERNANCE.PII_CATEGORY = 'PHONE';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN DATE_OF_BIRTH
        SET TAG GOVERNANCE.SENSITIVITY = 'RESTRICTED',
                GOVERNANCE.PII_CATEGORY = 'DATE_OF_BIRTH';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN SSN
        SET TAG GOVERNANCE.SENSITIVITY = 'RESTRICTED',
                GOVERNANCE.PII_CATEGORY = 'SSN';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.CUSTOMERS
    MODIFY COLUMN STREET_ADDRESS
        SET TAG GOVERNANCE.SENSITIVITY = 'CONFIDENTIAL',
                GOVERNANCE.PII_CATEGORY = 'ADDRESS';


-- ── B4.  Tag sensitive columns in CURATED.EMPLOYEES ─────────

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN FIRST_NAME
        SET TAG GOVERNANCE.SENSITIVITY = 'CONFIDENTIAL',
                GOVERNANCE.PII_CATEGORY = 'NAME';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN LAST_NAME
        SET TAG GOVERNANCE.SENSITIVITY = 'CONFIDENTIAL',
                GOVERNANCE.PII_CATEGORY = 'NAME';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN EMAIL
        SET TAG GOVERNANCE.SENSITIVITY = 'RESTRICTED',
                GOVERNANCE.PII_CATEGORY = 'EMAIL';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN PHONE
        SET TAG GOVERNANCE.SENSITIVITY = 'CONFIDENTIAL',
                GOVERNANCE.PII_CATEGORY = 'PHONE';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN DATE_OF_BIRTH
        SET TAG GOVERNANCE.SENSITIVITY = 'RESTRICTED',
                GOVERNANCE.PII_CATEGORY = 'DATE_OF_BIRTH';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN SSN
        SET TAG GOVERNANCE.SENSITIVITY = 'RESTRICTED',
                GOVERNANCE.PII_CATEGORY = 'SSN';

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.EMPLOYEES
    MODIFY COLUMN ANNUAL_SALARY
        SET TAG GOVERNANCE.SENSITIVITY = 'RESTRICTED',
                GOVERNANCE.PII_CATEGORY = 'SALARY';


-- ── B5.  Tag ORDERS payment column ───────────────────────────

ALTER TABLE METADATA_WORKSHOP_DB.CURATED.ORDERS
    MODIFY COLUMN CREDIT_CARD_LAST4
        SET TAG GOVERNANCE.SENSITIVITY = 'RESTRICTED',
                GOVERNANCE.PII_CATEGORY = 'PAYMENT_CARD';


-- ============================================================
-- SECTION C — Query applied tags
-- ============================================================
/*
  TAG_REFERENCES is an INFORMATION_SCHEMA table function that returns
  all tags applied to objects within the current database.
*/

-- C1. All table-level tags in the workshop database
SELECT
    TAG_DATABASE,
    TAG_SCHEMA,
    TAG_NAME,
    TAG_VALUE,
    OBJECT_DATABASE,
    OBJECT_SCHEMA,
    OBJECT_NAME,
    DOMAIN                              AS object_type,
    COLUMN_NAME
FROM TABLE(
    METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
        'METADATA_WORKSHOP_DB.CURATED.CUSTOMERS',
        'TABLE'
    )
);


-- C2. All column-level tags across every CURATED table
--     (run once per table — Snowflake doesn't yet support cross-table tag scans
--      in a single TAG_REFERENCES call, so we UNION the tables of interest)

SELECT 'CUSTOMERS'   AS table_name, TAG_NAME, TAG_VALUE, COLUMN_NAME
FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'))
UNION ALL
SELECT 'EMPLOYEES',  TAG_NAME, TAG_VALUE, COLUMN_NAME
FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.EMPLOYEES', 'TABLE'))
UNION ALL
SELECT 'ORDERS',     TAG_NAME, TAG_VALUE, COLUMN_NAME
FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.ORDERS', 'TABLE'))
ORDER BY table_name, COLUMN_NAME, TAG_NAME;


-- C3. Find every RESTRICTED column across the database
SELECT
    OBJECT_NAME                         AS table_name,
    COLUMN_NAME,
    TAG_NAME,
    TAG_VALUE
FROM TABLE(
    METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
        'METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'
    )
)
WHERE TAG_NAME = 'SENSITIVITY'
  AND TAG_VALUE = 'RESTRICTED';


-- ============================================================
-- SECTION D — Tag inheritance
-- ============================================================
/*
  Snowflake supports tag inheritance: a tag applied at the TABLE level
  is visible on all columns of that table unless overridden at the column level.

  This means you can apply a blanket SENSITIVITY = 'CONFIDENTIAL' at the
  table level, then override specific columns with SENSITIVITY = 'RESTRICTED'.
*/

-- D1. Check effective sensitivity for every column (column tag wins over table tag)
--     This simulates a governance report of "what is the effective sensitivity?"
SELECT
    COLUMN_NAME,
    TAG_NAME,
    TAG_VALUE,
    LEVEL                               -- 'COLUMN' or 'TABLE'
FROM TABLE(
    METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
        'METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'
    )
)
WHERE TAG_NAME = 'SENSITIVITY'
ORDER BY COLUMN_NAME;


-- ============================================================
-- SECTION E — Tag-based data inventory view
-- ============================================================
/*
  Build a reusable view in GOVERNANCE that summarises every tagged column.
  This becomes the "single source of truth" for downstream policy automation.
*/
USE ROLE DATA_GOVERNOR;
USE SCHEMA GOVERNANCE;

CREATE OR REPLACE VIEW GOVERNANCE.V_SENSITIVE_COLUMN_INVENTORY AS
    SELECT 'CURATED.CUSTOMERS'    AS qualified_table, COLUMN_NAME, TAG_NAME, TAG_VALUE, LEVEL
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'))
    WHERE TAG_NAME IN ('SENSITIVITY', 'PII_CATEGORY')
UNION ALL
    SELECT 'CURATED.EMPLOYEES',   COLUMN_NAME, TAG_NAME, TAG_VALUE, LEVEL
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.EMPLOYEES', 'TABLE'))
    WHERE TAG_NAME IN ('SENSITIVITY', 'PII_CATEGORY')
UNION ALL
    SELECT 'CURATED.ORDERS',      COLUMN_NAME, TAG_NAME, TAG_VALUE, LEVEL
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.ORDERS', 'TABLE'))
    WHERE TAG_NAME IN ('SENSITIVITY', 'PII_CATEGORY');

-- Query the inventory
SELECT *
FROM GOVERNANCE.V_SENSITIVE_COLUMN_INVENTORY
ORDER BY qualified_table, COLUMN_NAME, TAG_NAME;


-- ============================================================
-- REFLECTION QUESTIONS
-- ============================================================
/*
  1. What happens if someone adds a new column to CURATED.CUSTOMERS that
     contains email addresses but forgets to apply a tag?  How would you
     detect this gap automatically?

  2. Why is it better to attach masking policies to TAGS rather than to
     individual column names?

  3. How does the "controlled vocabulary" on a tag (ALLOWED_VALUES) help
     enforce consistent metadata across teams?

  4. Design a tag strategy for a new FINANCE schema that will contain
     revenue, cost, and budget data.  What tags would you create and what
     values would you allow?
*/

-- ============================================================
-- Next step: Run exercises/03_dynamic_data_masking.sql
-- ============================================================
