/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : 05_data_classification.sql
  Exercise: Automated and Manual Data Classification

  Principle: "Observe continuously — use metadata to find what you don't
              know you have."
  Data classification combines automated pattern-matching (Snowflake's
  native classification service) with manual review to build a comprehensive,
  always-current picture of sensitive data across the platform.

  Topics covered:
    A. Snowflake's built-in EXTRACT_SEMANTIC_CATEGORIES function
    B. Reviewing classification recommendations
    C. Applying categories as tags (promoting recommendations to facts)
    D. Building a classification coverage report
    E. Scheduling classification scans with Tasks

  Run as  : DATA_ENGINEER or DATA_GOVERNOR
  Requires: exercises/02_object_tagging.sql
================================================================================
*/

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE METADATA_WORKSHOP_DB;
USE SCHEMA   CURATED;


-- ============================================================
-- SECTION A — Snowflake's Automatic Data Classification
-- ============================================================
/*
  EXTRACT_SEMANTIC_CATEGORIES scans a sample of rows in a table and
  returns JSON with recommended semantic category and privacy category
  for each column.

  NOTE: This feature is available on Business Critical Edition and above,
  or on Trial accounts with sensitive data features enabled.
  If not available, skip to Section C (manual classification).
*/

-- A1. Run auto-classification on CURATED.CUSTOMERS
SELECT EXTRACT_SEMANTIC_CATEGORIES('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS');

/*
  SAMPLE OUTPUT (abbreviated):
  {
    "EMAIL": {
      "recommendation": {
        "semantic_category": "EMAIL",
        "privacy_category": "IDENTIFIER",
        "confidence": "HIGH",
        "coverage": 1.0
      }
    },
    "SSN": {
      "recommendation": {
        "semantic_category": "US_SSN",
        "privacy_category": "SENSITIVE",
        "confidence": "HIGH",
        "coverage": 1.0
      }
    },
    ...
  }
*/

-- A2. Run auto-classification on CURATED.EMPLOYEES
SELECT EXTRACT_SEMANTIC_CATEGORIES('METADATA_WORKSHOP_DB.CURATED.EMPLOYEES');


-- A3. Parse the JSON output to get a flat, readable report
WITH raw_result AS (
    SELECT EXTRACT_SEMANTIC_CATEGORIES('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS') AS classification_result
),
parsed AS (
    SELECT
        key                                                            AS column_name,
        value:recommendation:semantic_category::VARCHAR               AS semantic_category,
        value:recommendation:privacy_category::VARCHAR                AS privacy_category,
        value:recommendation:confidence::VARCHAR                      AS confidence,
        ROUND(value:recommendation:coverage::FLOAT, 2)                AS coverage_pct
    FROM raw_result,
         LATERAL FLATTEN(INPUT => classification_result)
)
SELECT
    'CUSTOMERS'     AS table_name,
    column_name,
    semantic_category,
    privacy_category,
    confidence,
    coverage_pct
FROM parsed
WHERE semantic_category IS NOT NULL
ORDER BY privacy_category, column_name;


-- ============================================================
-- SECTION B — Reviewing and Accepting Recommendations
-- ============================================================
/*
  AUTO_TAG applies classification results as Snowflake system tags
  (snowflake.core.semantic_category and snowflake.core.privacy_category).
  Think of this as "promoting recommendations to facts."
*/

-- B1. Apply system tags to CURATED.CUSTOMERS
CALL ASSOCIATE_SEMANTIC_CATEGORY_TAGS(
    'METADATA_WORKSHOP_DB.CURATED.CUSTOMERS',
    EXTRACT_SEMANTIC_CATEGORIES('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS')
);

-- B2. Apply system tags to CURATED.EMPLOYEES
CALL ASSOCIATE_SEMANTIC_CATEGORY_TAGS(
    'METADATA_WORKSHOP_DB.CURATED.EMPLOYEES',
    EXTRACT_SEMANTIC_CATEGORIES('METADATA_WORKSHOP_DB.CURATED.EMPLOYEES')
);

-- B3. Apply system tags to CURATED.ORDERS
CALL ASSOCIATE_SEMANTIC_CATEGORY_TAGS(
    'METADATA_WORKSHOP_DB.CURATED.ORDERS',
    EXTRACT_SEMANTIC_CATEGORIES('METADATA_WORKSHOP_DB.CURATED.ORDERS')
);


-- B4. Review applied system tags (semantic and privacy categories)
SELECT
    COLUMN_NAME,
    TAG_NAME,
    TAG_VALUE
FROM TABLE(
    METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
        'METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'
    )
)
WHERE TAG_NAME ILIKE '%semantic%'
   OR TAG_NAME ILIKE '%privacy%'
ORDER BY COLUMN_NAME, TAG_NAME;


-- ============================================================
-- SECTION C — Manual Classification for Business-Context Tags
-- ============================================================
/*
  Snowflake's automatic classifier understands technical categories
  (US_SSN, EMAIL, etc.) but not your business taxonomy.
  Manual tagging fills that gap:
    - GOVERNANCE.SENSITIVITY levels (from exercise 02)
    - GOVERNANCE.PII_CATEGORY values
    - GOVERNANCE.DATA_DOMAIN
    - GOVERNANCE.RETENTION_PERIOD

  We already applied business tags in exercise 02.
  In this section we build a RECONCILIATION query to detect mismatches
  between system classification and your manual classification.
*/

-- C1. Compare system semantic_category with workshop PII_CATEGORY tag
--     Flag any column where the system detected a sensitive type but
--     no manual PII_CATEGORY tag has been applied
WITH system_tags AS (
    SELECT
        COLUMN_NAME,
        TAG_VALUE   AS system_semantic_category
    FROM TABLE(
        METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
            'METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'
        )
    )
    WHERE TAG_NAME ILIKE '%semantic%'
      AND TAG_VALUE NOT IN ('', 'NONE')
),
manual_tags AS (
    SELECT
        COLUMN_NAME,
        TAG_VALUE   AS manual_pii_category
    FROM TABLE(
        METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
            'METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'
        )
    )
    WHERE TAG_NAME = 'PII_CATEGORY'
)
SELECT
    s.COLUMN_NAME,
    s.system_semantic_category,
    m.manual_pii_category,
    CASE
        WHEN m.manual_pii_category IS NULL THEN 'MISSING MANUAL TAG — review required'
        ELSE 'OK'
    END AS classification_status
FROM system_tags s
LEFT JOIN manual_tags m USING (COLUMN_NAME)
ORDER BY classification_status DESC, COLUMN_NAME;


-- ============================================================
-- SECTION D — Classification Coverage Report
-- ============================================================
/*
  A coverage report answers: "What percentage of our sensitive columns
  have been classified and have masking policies?"
  This is a key governance KPI.
*/

-- D1. Coverage summary per table
WITH all_columns AS (
    SELECT TABLE_NAME, COLUMN_NAME
    FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'CURATED'
),
tagged_columns AS (
    SELECT 'CUSTOMERS' AS table_name, COLUMN_NAME
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.CUSTOMERS', 'TABLE'))
    WHERE TAG_NAME = 'PII_CATEGORY' AND TAG_VALUE != 'NONE'
    UNION ALL
    SELECT 'EMPLOYEES', COLUMN_NAME
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.EMPLOYEES', 'TABLE'))
    WHERE TAG_NAME = 'PII_CATEGORY' AND TAG_VALUE != 'NONE'
    UNION ALL
    SELECT 'ORDERS', COLUMN_NAME
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.ORDERS', 'TABLE'))
    WHERE TAG_NAME = 'PII_CATEGORY' AND TAG_VALUE != 'NONE'
    UNION ALL
    SELECT 'PRODUCTS', COLUMN_NAME
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.PRODUCTS', 'TABLE'))
    WHERE TAG_NAME = 'PII_CATEGORY' AND TAG_VALUE != 'NONE'
    UNION ALL
    SELECT 'ORDER_ITEMS', COLUMN_NAME
    FROM TABLE(METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('METADATA_WORKSHOP_DB.CURATED.ORDER_ITEMS', 'TABLE'))
    WHERE TAG_NAME = 'PII_CATEGORY' AND TAG_VALUE != 'NONE'
)
SELECT
    ac.TABLE_NAME,
    COUNT(DISTINCT ac.COLUMN_NAME)                              AS total_columns,
    COUNT(DISTINCT tc.COLUMN_NAME)                              AS tagged_pii_columns,
    ROUND(
        COUNT(DISTINCT tc.COLUMN_NAME) * 100.0 /
        NULLIF(COUNT(DISTINCT ac.COLUMN_NAME), 0),
    1)                                                          AS pct_pii_tagged
FROM all_columns ac
LEFT JOIN tagged_columns tc
  ON ac.TABLE_NAME = tc.table_name
 AND ac.COLUMN_NAME = tc.COLUMN_NAME
GROUP BY ac.TABLE_NAME
ORDER BY pct_pii_tagged DESC NULLS LAST;


-- ============================================================
-- SECTION E — Automating Classification with a Snowflake Task
-- ============================================================
/*
  In production you want classification to run automatically on a schedule
  so that new tables are classified without manual intervention.

  The Task below runs a stored procedure that:
    1. Finds all unclassified tables in CURATED schema
    2. Runs EXTRACT_SEMANTIC_CATEGORIES on each
    3. Calls ASSOCIATE_SEMANTIC_CATEGORY_TAGS to apply the results

  NOTE: Tasks consume compute credits.  In this workshop we create the
  task but leave it SUSPENDED.  Resume it in production with:
    ALTER TASK GOVERNANCE.CLASSIFY_CURATED_TABLES RESUME;
*/

USE ROLE DATA_ENGINEER;
USE SCHEMA GOVERNANCE;

-- E1. Stored procedure to classify all tables in CURATED
CREATE OR REPLACE PROCEDURE GOVERNANCE.SP_CLASSIFY_CURATED()
    RETURNS VARCHAR
    LANGUAGE JAVASCRIPT
    EXECUTE AS CALLER
AS
$$
    var tables_to_classify = [];
    var find_tables = snowflake.execute({
        sqlText: `
            SELECT TABLE_NAME
            FROM METADATA_WORKSHOP_DB.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'CURATED'
              AND TABLE_TYPE   = 'BASE TABLE'
        `
    });

    while (find_tables.next()) {
        tables_to_classify.push(find_tables.getColumnValue('TABLE_NAME'));
    }

    var classified = 0;
    tables_to_classify.forEach(function(table_name) {
        var qualified = 'METADATA_WORKSHOP_DB.CURATED.' + table_name;
        try {
            snowflake.execute({
                sqlText: `
                    CALL ASSOCIATE_SEMANTIC_CATEGORY_TAGS(
                        '` + qualified + `',
                        EXTRACT_SEMANTIC_CATEGORIES('` + qualified + `')
                    )
                `
            });
            classified++;
        } catch (err) {
            // Log but continue — some tables may not have classifiable content
        }
    });

    return 'Classified ' + classified + ' of ' + tables_to_classify.length + ' tables.';
$$;

-- E2. Test the stored procedure
CALL GOVERNANCE.SP_CLASSIFY_CURATED();


-- E3. Create a scheduled task (SUSPENDED — do not run in workshop)
CREATE OR REPLACE TASK GOVERNANCE.CLASSIFY_CURATED_TABLES
    WAREHOUSE   = WORKSHOP_WH
    SCHEDULE    = 'USING CRON 0 2 * * 0 UTC'   -- every Sunday at 02:00 UTC
    COMMENT     = 'Weekly auto-classification of all CURATED tables'
AS
    CALL GOVERNANCE.SP_CLASSIFY_CURATED();

-- Task starts SUSPENDED by default in Snowflake; no action needed to keep it suspended.
-- SHOW TASKS IN SCHEMA METADATA_WORKSHOP_DB.GOVERNANCE;


-- ============================================================
-- REFLECTION QUESTIONS
-- ============================================================
/*
  1. Snowflake's classifier works on a sample of rows.  What risks does
     this introduce and how would you mitigate them for a table that
     contains sensitive data only in certain rows (e.g., a catch-all
     "notes" column)?

  2. How would you handle classification in a multi-region deployment
     where different countries have different definitions of PII?

  3. What should trigger a re-classification run?  (Schema changes?
     New data loaded?  Time-based schedule?  All of the above?)

  4. Design a governance dashboard using the coverage report in Section D.
     What additional metrics would you track week-over-week?
*/

-- ============================================================
-- Next step: Run exercises/06_metadata_driven_architecture.sql
-- ============================================================
