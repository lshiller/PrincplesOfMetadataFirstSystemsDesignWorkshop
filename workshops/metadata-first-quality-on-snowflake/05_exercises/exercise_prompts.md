# Workshop Exercises — Metadata-First Data Quality on Snowflake

These exercises follow the **4-hour session agenda** described in the [workshop README](../README.md).  
Each exercise builds on the previous one; run the setup scripts in order before starting.

---

## Part 1 — Security & Scaffolding (0:20 – 0:50)

### Exercise 1.1 — Role verification
After running `00_setup/00_roles_and_grants.sql` and `00_setup/01_databases_and_schemas.sql`:

```sql
-- Switch to DATA_ENGINEER and confirm access
USE ROLE DATA_ENGINEER;
USE WAREHOUSE WORKSHOP_WH;

-- Create a test table (should succeed)
CREATE OR REPLACE TABLE QUALITY.PUBLIC.SMOKE_TEST (ID NUMBER);
DROP TABLE QUALITY.PUBLIC.SMOKE_TEST;

-- Switch to METADATA_STEWARD and confirm access
USE ROLE METADATA_STEWARD;
CREATE OR REPLACE TABLE QUALITY.PUBLIC.SMOKE_TEST (ID NUMBER);
DROP TABLE QUALITY.PUBLIC.SMOKE_TEST;
```

**Discussion:** What is the difference between `METADATA_STEWARD` and `DATA_ENGINEER`?  
When would you grant each role to a person on your team?

---

## Part 2 — Sample Data Exploration (0:50 – 1:30)

### Exercise 2.1 — Spot the problems
After running `01_sample_data/` scripts, run each query and describe what you see:

```sql
USE ROLE DATA_ENGINEER;

-- How many SAP customers are there?
SELECT COUNT(*) FROM CURATED.SAP.CUSTOMER;

-- How many Salesforce accounts have a SAP_CUSTOMER_ID?
SELECT COUNT(*) FROM CURATED.SALESFORCE.ACCOUNT WHERE SAP_CUSTOMER_ID IS NOT NULL;

-- Are there SAP customers with no SF account?
SELECT c.SAP_CUSTOMER_ID, c.CUSTOMER_NAME
FROM   CURATED.SAP.CUSTOMER c
LEFT   JOIN CURATED.SALESFORCE.ACCOUNT a ON a.SAP_CUSTOMER_ID = c.SAP_CUSTOMER_ID
WHERE  a.SF_ACCOUNT_ID IS NULL;

-- Are there duplicate SAP_CUSTOMER_ID values in SF accounts?
SELECT SAP_CUSTOMER_ID, COUNT(*) AS CNT
FROM   CURATED.SALESFORCE.ACCOUNT
GROUP  BY SAP_CUSTOMER_ID
HAVING COUNT(*) > 1;

-- Are there name mismatches?
SELECT c.SAP_CUSTOMER_ID, c.CUSTOMER_NAME, a.ACCOUNT_NAME
FROM   CURATED.SAP.CUSTOMER c
JOIN   CURATED.SALESFORCE.ACCOUNT a ON a.SAP_CUSTOMER_ID = c.SAP_CUSTOMER_ID
WHERE  UPPER(TRIM(c.CUSTOMER_NAME)) != UPPER(TRIM(a.ACCOUNT_NAME));
```

**Discussion:** Before we formalize these as tests — what's the difference between  
running these ad-hoc queries and having them registered in `QUALITY.PUBLIC.TEST`?

---

## Part 3 — The Test Registry (1:30 – 2:20)

### Exercise 3.1 — Read the metadata
After running `02_quality_framework/` scripts:

```sql
USE ROLE METADATA_STEWARD;

-- See all registered tests
SELECT ID, NAME, TEST_TYPE, SEVERITY, ENABLED, ON_FAIL_ACTION
FROM   QUALITY.PUBLIC.TEST
ORDER  BY ID;
```

### Exercise 3.2 — Register your own test (before writing the view!)
This is the metadata-first principle in action: **register the test before implementing it**.

```sql
-- Pick an ID in the 200–299 range for your personal exercises
INSERT INTO QUALITY.PUBLIC.TEST
    (ID, NAME, TEST_TYPE, DESCRIPTION, SEVERITY, ENABLED, ON_FAIL_ACTION)
VALUES (
    200,
    'My First Test',          -- give it a real name
    'BUSINESS',
    'Describe what this test checks and why it matters.',
    'MEDIUM',
    TRUE,
    'NOTIFY'
);
```

Now run Test 1 (`SELECT * FROM QUALITY.PUBLIC.TEST_1`).  
**What do you see, and why?**

---

## Part 4 — Writing Test Views (2:20 – 3:25)

### Exercise 4.1 — Run the existing tests manually
```sql
USE ROLE METADATA_STEWARD;

-- After creating all views in 03_tests/:
SELECT * FROM QUALITY.PUBLIC.TEST_1;    -- metadata: missing views
SELECT * FROM QUALITY.PUBLIC.TEST_2;    -- metadata: contract columns
SELECT * FROM QUALITY.PUBLIC.TEST_101;  -- business: SAP missing in SF
SELECT * FROM QUALITY.PUBLIC.TEST_102;  -- business: duplicate mapping
SELECT * FROM QUALITY.PUBLIC.TEST_103;  -- business: name mismatch
```

Expected results with the workshop seed data:
| Test | Rows returned | Reason |
|------|--------------|--------|
| 1    | 0            | All test views created |
| 2    | 0            | All views are contract-compliant |
| 101  | 1            | Initech LLC (SAP 1003) has no SF account |
| 102  | 1            | Umbrella Co (SAP 1004) maps to A003 and A004 |
| 103  | 1            | Globex Inc vs Globex Incorporated |

### Exercise 4.2 — Implement your registered test (ID 200)
Create the view for the test you registered in Exercise 3.2.  
Your view **must** follow the failure contract (CoC):

```sql
CREATE OR REPLACE VIEW QUALITY.PUBLIC.TEST_200 AS
SELECT
    200                                                              AS TEST_ID,
    'My First Test'                                                  AS TEST_NAME,
    '<describe the failure>'                                         AS FAILURE_REASON,
    '<the key that identifies the failing record>'                   AS RECORD_KEY,
    OBJECT_CONSTRUCT(
        'key1', value1,
        'key2', value2
    )                                                                AS RECORD_PAYLOAD,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ      AS DETECTED_AT
FROM <your_source_table>
WHERE <your_failure_condition>;
```

After creating the view, re-run Test 1 and Test 2:
```sql
SELECT * FROM QUALITY.PUBLIC.TEST_1;  -- should no longer show ID 200
SELECT * FROM QUALITY.PUBLIC.TEST_2;  -- should return 0 rows if contract is met
```

### Exercise 4.3 — Break and fix a test (understanding the lifecycle)
1. Run `UPDATE CURATED.SAP.CUSTOMER SET CUSTOMER_NAME = 'Acme Corporation' WHERE SAP_CUSTOMER_ID = 1001;`
2. Run `SELECT * FROM QUALITY.PUBLIC.TEST_103;` — how many rows now?
3. Restore: `UPDATE CURATED.SAP.CUSTOMER SET CUSTOMER_NAME = 'Acme Corp' WHERE SAP_CUSTOMER_ID = 1001;`
4. Re-run Test 103 — confirm 0 additional rows.

**Discussion:** How is this different from a traditional unit test? How is it like one?

---

## Part 5 — Orchestration (3:25 – 4:00)

### Exercise 5.1 — Run all tests with the stored procedure
```sql
USE ROLE METADATA_STEWARD;
USE WAREHOUSE WORKSHOP_WH;

-- Run all enabled tests
CALL QUALITY.PUBLIC.RUN_ALL_TESTS('workshop run 1');

-- Inspect the results
SELECT ID, TEST_ID, TEST_NAME, STATUS, TEST_PASSED,
       RUN_TIME AS RUN_TIME_MS
FROM   QUALITY.TEST_RESULT.TEST_RESULT
ORDER  BY ID DESC
LIMIT  10;

-- Inspect the notification outbox
SELECT TEST_ID, TEST_NAME, SEVERITY, FAIL_TABLE_NAME, MESSAGE, CREATED_AT
FROM   QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX
ORDER  BY ID DESC;
```

### Exercise 5.2 — Explore a failure snapshot table
The orchestration procedure materialised a failure table for each failing test.

```sql
-- List all failure tables created today
SELECT TABLE_NAME, ROW_COUNT, CREATED
FROM   QUALITY.INFORMATION_SCHEMA.TABLES
WHERE  TABLE_SCHEMA = 'TEST_RESULT'
  AND  TABLE_NAME LIKE 'TEST_%_FAIL_%'
ORDER  BY CREATED DESC;

-- Read a failure table (replace with your actual table name)
-- SELECT * FROM QUALITY.TEST_RESULT.TEST_101_FAIL_<STAMP>;
```

**Discussion:** Why is a snapshot table more useful than simply re-querying the view after the run?

### Exercise 5.3 — Run only METADATA tests
```sql
CALL QUALITY.PUBLIC.RUN_ALL_TESTS('metadata-only pass', 'METADATA');

SELECT TEST_ID, TEST_NAME, TEST_PASSED, STATUS
FROM   QUALITY.TEST_RESULT.TEST_RESULT
ORDER  BY ID DESC
LIMIT  5;
```

### Exercise 5.4 — Disable a test
```sql
-- Temporarily disable Test 103 (name mismatch) while teams agree on naming
UPDATE QUALITY.PUBLIC.TEST
   SET ENABLED = FALSE
 WHERE ID = 103;

CALL QUALITY.PUBLIC.RUN_ALL_TESTS('after disabling test 103');

-- Re-enable
UPDATE QUALITY.PUBLIC.TEST
   SET ENABLED = TRUE
 WHERE ID = 103;
```

**Discussion:** How does the `ENABLED` column embody the "metadata drives behaviour" principle?

### Exercise 5.5 — Automation stub invocation
Test 101 has `ON_FAIL_ACTION = 'CALL_PROC'` and `ON_FAIL_PROC_NAME = 'QUALITY.PUBLIC.ON_FAIL_STUB'`.

```sql
-- After a run, check the stub audit log
SELECT TEST_RESULT_ID, INVOKED_AT, NOTE
FROM   QUALITY.TEST_RESULT.AUTOMATION_STUB_LOG
ORDER  BY ID DESC;
```

**Discussion:** What would you put in `ON_FAIL_STUB` to:
- Create a Salesforce account for the missing SAP customer?
- Send a Slack notification?
- Open a Jira ticket?

---

## Bonus Exercises

### Bonus A — Add a third metadata-first test
Register and implement a test that checks:  
*"Every enabled test has a non-null DESCRIPTION."*

Hint: the view queries `QUALITY.PUBLIC.TEST` itself.

```sql
-- Register:
INSERT INTO QUALITY.PUBLIC.TEST (ID, NAME, TEST_TYPE, DESCRIPTION, SEVERITY, ENABLED, ON_FAIL_ACTION)
VALUES (3, 'All Tests Have Descriptions', 'METADATA',
        'Every enabled test must have a non-null, non-empty DESCRIPTION.',
        'LOW', TRUE, 'NONE');

-- Implement:
CREATE OR REPLACE VIEW QUALITY.PUBLIC.TEST_3 AS
SELECT
    3                                                                AS TEST_ID,
    'All Tests Have Descriptions'                                    AS TEST_NAME,
    'Test is missing a DESCRIPTION: ID=' || ID::VARCHAR             AS FAILURE_REASON,
    ID::VARCHAR                                                      AS RECORD_KEY,
    OBJECT_CONSTRUCT('test_id', ID, 'test_name', NAME)              AS RECORD_PAYLOAD,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ      AS DETECTED_AT
FROM QUALITY.PUBLIC.TEST
WHERE ENABLED = TRUE
  AND (DESCRIPTION IS NULL OR TRIM(DESCRIPTION) = '');
```

### Bonus B — Severity-filtered runs
Modify the orchestration call to simulate a "gate" that only fails on HIGH severity:

```sql
-- Run all tests, then check if any HIGH severity tests failed
CALL QUALITY.PUBLIC.RUN_ALL_TESTS('gate check');

SELECT COUNT(*) AS HIGH_SEVERITY_FAILURES
FROM   QUALITY.TEST_RESULT.TEST_RESULT       tr
JOIN   QUALITY.PUBLIC.TEST                   t ON t.ID = tr.TEST_ID
WHERE  tr.STATUS      = 'COMPLETED'
  AND  tr.TEST_PASSED = FALSE
  AND  t.SEVERITY     = 'HIGH'
  AND  tr.ID = (SELECT MAX(ID) FROM QUALITY.TEST_RESULT.TEST_RESULT
                WHERE TEST_ID = t.ID);
```

**Discussion:** How would you use this query in a CI/CD pipeline to block a deployment?

### Bonus C — Cleanup procedure for failure tables
The problem statement mentions a separate cleanup process. Design one:

```sql
-- Sketch: delete failure tables older than N days
CREATE OR REPLACE PROCEDURE QUALITY.TEST_RESULT.CLEANUP_FAIL_TABLES(RETAIN_DAYS NUMBER DEFAULT 30)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
-- Your implementation here
-- Hint: query QUALITY.INFORMATION_SCHEMA.TABLES for TABLE_NAME LIKE 'TEST_%_FAIL_%'
--       and CREATED < DATEADD(DAY, -RETAIN_DAYS, CURRENT_DATE)
-- Then EXECUTE IMMEDIATE 'DROP TABLE ' || table_name for each
RETURN 'TODO';
$$;
```
