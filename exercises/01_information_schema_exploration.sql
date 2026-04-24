/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : 01_information_schema_exploration.sql
  Exercise: Mining Snowflake Metadata with INFORMATION_SCHEMA & ACCOUNT_USAGE

  Principle: "Discover before you build."
  Before writing a single byte of business logic, query the platform's metadata
  to understand what already exists — tables, columns, data types, sizes,
  dependencies, and usage patterns.

  Topics covered:
    A. INFORMATION_SCHEMA vs ACCOUNT_USAGE — when to use each
    B. Discovering tables, columns, and data types
    C. Measuring table sizes and activity
    D. Finding columns by data type or naming pattern (sensitive data discovery)
    E. Query history — what is actually being used?

  Run as  : DATA_ENGINEER or DATA_ANALYST
  Requires: setup/00_environment_setup.sql + setup/01_sample_data.sql
================================================================================
*/

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE METADATA_WORKSHOP_DB;
USE SCHEMA   CURATED;

-- ============================================================
-- SECTION A — INFORMATION_SCHEMA vs ACCOUNT_USAGE
-- ============================================================
/*
  INFORMATION_SCHEMA   : Per-database view; near real-time; limited to 10,000
                         objects per query; no historical data; requires USAGE
                         on the database.

  SNOWFLAKE.ACCOUNT_USAGE : Account-wide; 45-minute to 3-hour latency; full
                         history (up to 365 days); requires ACCOUNTADMIN or a
                         role granted the SNOWFLAKE database privilege.

  Rule of thumb:
    - Use INFORMATION_SCHEMA for "what is in this database right now?"
    - Use ACCOUNT_USAGE     for "what happened across the account over time?"
*/


-- ============================================================
-- SECTION B — Discovering tables and columns
-- ============================================================

-- B1. List every table in the workshop database with its schema and row count
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE,
    ROW_COUNT,
    BYTES,
    ROUND(BYTES / POWER(1024, 2), 3)  AS SIZE_MB,
    CREATED,
    LAST_ALTERED,
    COMMENT
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
ORDER BY TABLE_SCHEMA, TABLE_NAME;


-- B2. Inspect every column in CURATED tables — name, type, nullability, default
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    COMMENT
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CURATED'
ORDER BY TABLE_NAME, ORDINAL_POSITION;


-- B3. How many columns per table?
SELECT
    TABLE_NAME,
    COUNT(*) AS column_count
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CURATED'
GROUP BY TABLE_NAME
ORDER BY column_count DESC;


-- ============================================================
-- SECTION C — Measuring size and activity
-- ============================================================

-- C1. Table sizes across all non-system schemas
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    ROW_COUNT,
    BYTES,
    ROUND(BYTES / POWER(1024, 2), 3)    AS SIZE_MB,
    LAST_ALTERED
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY BYTES DESC NULLS LAST;


-- C2. Storage by schema (useful for cost attribution)
SELECT
    TABLE_SCHEMA,
    COUNT(*)                            AS table_count,
    SUM(ROW_COUNT)                      AS total_rows,
    SUM(BYTES)                          AS total_bytes,
    ROUND(SUM(BYTES) / POWER(1024, 2), 3) AS total_size_mb
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
  AND TABLE_TYPE = 'BASE TABLE'
GROUP BY TABLE_SCHEMA
ORDER BY total_bytes DESC NULLS LAST;


-- ============================================================
-- SECTION D — Finding sensitive columns by naming pattern
-- ============================================================
/*
  A core Metadata-First practice: before applying masking policies, query the
  metadata to find ALL columns that look like they contain sensitive data.
  This ensures nothing slips through the cracks.
*/

-- D1. Find columns whose names suggest PII (email, phone, SSN, address, DOB)
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
  AND (
        COLUMN_NAME ILIKE '%email%'
     OR COLUMN_NAME ILIKE '%phone%'
     OR COLUMN_NAME ILIKE '%ssn%'
     OR COLUMN_NAME ILIKE '%social%'
     OR COLUMN_NAME ILIKE '%birth%'
     OR COLUMN_NAME ILIKE '%dob%'
     OR COLUMN_NAME ILIKE '%address%'
     OR COLUMN_NAME ILIKE '%credit_card%'
     OR COLUMN_NAME ILIKE '%salary%'
  )
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME;

/*
  DISCUSSION:
    How many potential PII columns did you find?
    Did any surprise you?
    Which schemas contain the most sensitive data?

  KEY INSIGHT:
    We found these columns WITHOUT opening a single table definition manually.
    This query is the foundation of automated sensitive-data discovery.
*/


-- D2. Find all DATE/TIMESTAMP columns (candidates for retention policies)
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
  AND DATA_TYPE IN ('DATE', 'TIMESTAMP_NTZ', 'TIMESTAMP_LTZ', 'TIMESTAMP_TZ')
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;


-- D3. Generate a "data inventory" CSV-ready summary
SELECT
    TABLE_SCHEMA                        AS schema_name,
    TABLE_NAME                          AS table_name,
    COLUMN_NAME                         AS column_name,
    DATA_TYPE                           AS data_type,
    CASE
        WHEN COLUMN_NAME ILIKE '%email%'        THEN 'EMAIL'
        WHEN COLUMN_NAME ILIKE '%phone%'        THEN 'PHONE'
        WHEN COLUMN_NAME ILIKE '%ssn%'          THEN 'SSN'
        WHEN COLUMN_NAME ILIKE '%birth%'
          OR COLUMN_NAME ILIKE '%dob%'          THEN 'DATE_OF_BIRTH'
        WHEN COLUMN_NAME ILIKE '%address%'      THEN 'ADDRESS'
        WHEN COLUMN_NAME ILIKE '%credit_card%'  THEN 'PAYMENT_CARD'
        WHEN COLUMN_NAME ILIKE '%salary%'       THEN 'SALARY'
        ELSE 'NON_SENSITIVE'
    END                                 AS sensitivity_category
FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
ORDER BY sensitivity_category, TABLE_SCHEMA, TABLE_NAME;


-- ============================================================
-- SECTION E — Query history (ACCOUNT_USAGE)
-- ============================================================
/*
  NOTE: ACCOUNT_USAGE views require the SNOWFLAKE database privilege or
  ACCOUNTADMIN role.  If your role cannot access these views, ask your
  ACCOUNTADMIN to grant: GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE
  TO ROLE DATA_ENGINEER;
*/

-- E1. Most frequently queried tables in the last 30 days
--     (helps prioritise which objects most need governance controls)
SELECT
    qh.QUERY_TYPE,
    at.TABLE_NAME,
    at.TABLE_SCHEMA,
    at.TABLE_CATALOG,
    COUNT(DISTINCT qh.QUERY_ID)         AS query_count,
    COUNT(DISTINCT qh.USER_NAME)        AS distinct_users
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY          qh
JOIN SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY         ah
  ON qh.QUERY_ID = ah.QUERY_ID
JOIN LATERAL FLATTEN(INPUT => ah.BASE_OBJECTS_ACCESSED) AS f
JOIN LATERAL (
    SELECT
        f.value:objectName::STRING      AS TABLE_NAME,
        f.value:objectDomain::STRING    AS object_domain,
        SPLIT_PART(f.value:objectName::STRING, '.', 2) AS TABLE_SCHEMA,
        SPLIT_PART(f.value:objectName::STRING, '.', 1) AS TABLE_CATALOG
    ) AS at
WHERE qh.START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND at.TABLE_CATALOG = 'METADATA_WORKSHOP_DB'
  AND at.object_domain = 'Table'
GROUP BY 1, 2, 3, 4
ORDER BY query_count DESC
LIMIT 20;


-- E2. Who is querying the workshop database?
SELECT
    USER_NAME,
    ROLE_NAME,
    COUNT(*)                            AS query_count,
    SUM(TOTAL_ELAPSED_TIME) / 1000.0   AS total_elapsed_sec,
    MIN(START_TIME)                     AS first_query,
    MAX(START_TIME)                     AS last_query
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE DATABASE_NAME = 'METADATA_WORKSHOP_DB'
  AND START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY USER_NAME, ROLE_NAME
ORDER BY query_count DESC;


-- ============================================================
-- REFLECTION QUESTIONS
-- ============================================================
/*
  1. What is the advantage of discovering sensitive columns via
     INFORMATION_SCHEMA rather than manually reviewing table DDL?

  2. How would you automate the "sensitivity_category" derivation (query D3)
     to run every time a new table is created?

  3. Why might ACCOUNT_USAGE data be 45 minutes old? What design consequences
     does that have for real-time governance decisions?

  4. Which tables in the CURATED schema have the most PII columns?
     Should those tables have stricter access controls than others?
*/

-- ============================================================
-- Next step: Run exercises/02_object_tagging.sql
-- ============================================================
