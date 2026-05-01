# Metadata-First Data Quality on Snowflake

**A 4-hour workshop** — build a metadata-driven test bed from scratch on a free Snowflake trial.

---

## Learning objectives

By the end of this session participants will:

- Understand the **metadata-first** approach to data quality: the test registry is the product
- Apply **Convention over Configuration (CoC)** so a single naming rule drives all test execution
- Write **DRY** orchestration that reads behaviour from metadata instead of hardcoding logic
- Implement two flavours of quality test views — **metadata compliance** and **cross-system business**
- Run a full automated test suite with persisted run results, failure snapshots, and a notification outbox
- Extend the framework with new tests in under 5 minutes (register row → create view → done)

---

## Prerequisites

- A [Snowflake free trial account](https://signup.snowflake.com/) (30 days, Enterprise Edition features included)
- Access to Snowsight (the browser-based Snowflake UI) or SnowSQL CLI
- No prior Snowflake Scripting (stored procedures) experience required

---

## Repository layout

```
workshops/metadata-first-quality-on-snowflake/
├── README.md                          ← this file
├── 00_setup/
│   ├── 00_roles_and_grants.sql        ← security foundation
│   └── 01_databases_and_schemas.sql   ← database/schema scaffolding
├── 01_sample_data/
│   ├── 00_curated_tables.sql          ← CURATED database DDL
│   ├── 01_seed_sap.sql                ← SAP sample data (intentionally dirty)
│   └── 02_seed_salesforce.sql         ← Salesforce sample data (intentionally dirty)
├── 02_quality_framework/
│   ├── 00_test_registry.sql           ← QUALITY.PUBLIC.TEST table
│   ├── 01_seed_test_registry.sql      ← register 5 example tests
│   └── 02_test_result_tables.sql      ← TEST_RESULT + NOTIFICATION_OUTBOX
├── 03_tests/
│   ├── test_0001_view_exists_for_enabled_tests.sql
│   ├── test_0002_view_contract_columns.sql
│   ├── test_0101_sap_customer_missing_in_sf.sql
│   ├── test_0102_sf_duplicate_sap_mapping.sql
│   └── test_0103_sap_sf_name_mismatch.sql
├── 04_orchestration/
│   ├── 00_run_all_tests_procedure.sql ← main orchestration stored procedure
│   └── 01_automation_stub_procedure.sql ← stub for metadata-driven automation
└── 05_exercises/
    └── exercise_prompts.md            ← 4-hour session exercises
```

---

## How to run the scripts (order matters)

Run scripts in the numbered order below. Each script is **idempotent** — safe to re-run.

| # | Script | Role | Description |
|---|--------|------|-------------|
| 1 | `00_setup/00_roles_and_grants.sql` | ACCOUNTADMIN | Create roles, warehouse, and grants |
| 2 | `00_setup/01_databases_and_schemas.sql` | ACCOUNTADMIN | Create QUALITY and CURATED databases |
| 3 | `01_sample_data/00_curated_tables.sql` | DATA_ENGINEER | Create CURATED.SAP and CURATED.SALESFORCE tables |
| 4 | `01_sample_data/01_seed_sap.sql` | DATA_ENGINEER | Seed SAP sample data |
| 5 | `01_sample_data/02_seed_salesforce.sql` | DATA_ENGINEER | Seed Salesforce sample data |
| 6 | `02_quality_framework/00_test_registry.sql` | METADATA_STEWARD | Create QUALITY.PUBLIC.TEST |
| 7 | `02_quality_framework/01_seed_test_registry.sql` | METADATA_STEWARD | Register 5 example tests |
| 8 | `02_quality_framework/02_test_result_tables.sql` | METADATA_STEWARD | Create TEST_RESULT and NOTIFICATION_OUTBOX |
| 9 | `03_tests/test_0001_*.sql` through `test_0103_*.sql` | METADATA_STEWARD | Create all 5 test views |
| 10 | `04_orchestration/00_run_all_tests_procedure.sql` | METADATA_STEWARD | Create the orchestration stored procedure |
| 11 | `04_orchestration/01_automation_stub_procedure.sql` | METADATA_STEWARD | Create the automation stub |

---

## The metadata-first quality framework

### Core convention (CoC)

> **To run a test, select from `QUALITY.PUBLIC.TEST_{ID}`.**

That single rule is the entire framework interface:

```sql
-- Run test 101 manually:
SELECT * FROM QUALITY.PUBLIC.TEST_101;
-- 0 rows = PASS;  >0 rows = FAIL (with diagnostic detail)
```

Everything else (orchestration, result persistence, failure materialisation, notifications) is derived
from this convention. No test IDs, no table names, no procedure names are hardcoded anywhere.

### The failure contract

Every test view **must** expose exactly these six columns. This is enforced by **Test 2** at runtime.

| Column | Type | Description |
|--------|------|-------------|
| `TEST_ID` | NUMBER | Matches `QUALITY.PUBLIC.TEST.ID` |
| `TEST_NAME` | VARCHAR | Matches `QUALITY.PUBLIC.TEST.NAME` |
| `FAILURE_REASON` | VARCHAR | Human-readable description of this specific failure |
| `RECORD_KEY` | VARCHAR | The identifying key of the failing record (for quick triage) |
| `RECORD_PAYLOAD` | VARIANT | Structured JSON detail (`OBJECT_CONSTRUCT(...)`) |
| `DETECTED_AT` | TIMESTAMP_NTZ | Timestamp (UTC) when the anomaly was detected |

### The test registry: `QUALITY.PUBLIC.TEST`

| Column | Description |
|--------|-------------|
| `ID` | Primary key; also names the view: `QUALITY.PUBLIC.TEST_{ID}` |
| `NAME` | Short human-readable test name |
| `CREATED_AT` | UTC timestamp — defaults to `CURRENT_TIMESTAMP()` |
| `DESCRIPTION` | What the test checks and why it matters |
| `TEST_TYPE` | `METADATA` (framework compliance) or `BUSINESS` (cross-system) |
| `OWNER_ROLE` | Snowflake role responsible for the test |
| `SEVERITY` | `LOW` \| `MEDIUM` \| `HIGH` |
| `ENABLED` | `FALSE` = skip during `RUN_ALL_TESTS()` |
| `ON_FAIL_ACTION` | `NONE` \| `NOTIFY` \| `CALL_PROC` — drives orchestration behaviour |
| `ON_FAIL_PROC_NAME` | Fully-qualified procedure to call when `ON_FAIL_ACTION = 'CALL_PROC'` |

**Key metadata-first principle:** `ON_FAIL_ACTION` and `ON_FAIL_PROC_NAME` encode *what happens on failure* directly in the registry row. The orchestration procedure reads these fields and acts accordingly — no hardcoded `IF test_id = 101 THEN ...` anywhere.

### Test ID convention (CoC)

| Range | Category |
|-------|----------|
| 1–99 | `METADATA` tests — framework compliance |
| 100–199 | `BUSINESS` tests — SAP ↔ Salesforce cross-system checks |
| 200+ | Participant exercises |

---

## How to add a new test (5-minute workflow)

### Step 1 — Register the test (metadata first!)
```sql
USE ROLE METADATA_STEWARD;

INSERT INTO QUALITY.PUBLIC.TEST
    (ID, NAME, TEST_TYPE, DESCRIPTION, SEVERITY, ENABLED, ON_FAIL_ACTION)
VALUES (
    200,                                -- pick an ID ≥ 200 for exercises
    'My New Quality Rule',
    'BUSINESS',
    'Describe what this checks and why it is important.',
    'HIGH',
    TRUE,
    'NOTIFY'
);
```

At this point the test is **registered but not implemented**. Test 1 will now fail for ID 200 —
intentionally surfacing the gap in the framework.

### Step 2 — Implement the view
```sql
CREATE OR REPLACE VIEW QUALITY.PUBLIC.TEST_200 AS
SELECT
    200                                                              AS TEST_ID,
    'My New Quality Rule'                                            AS TEST_NAME,
    '<describe the failure>'                                         AS FAILURE_REASON,
    <record_key_expression>::VARCHAR                                 AS RECORD_KEY,
    OBJECT_CONSTRUCT(
        'field_a', value_a,
        'field_b', value_b
    )                                                                AS RECORD_PAYLOAD,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ      AS DETECTED_AT
FROM <source_table>
WHERE <failure_condition>;
```

### Step 3 — Verify
```sql
SELECT * FROM QUALITY.PUBLIC.TEST_200;  -- 0 rows = pass
SELECT * FROM QUALITY.PUBLIC.TEST_1;    -- should no longer include ID 200
SELECT * FROM QUALITY.PUBLIC.TEST_2;    -- should return 0 rows if contract met
```

### Step 4 — Run the full suite
```sql
CALL QUALITY.PUBLIC.RUN_ALL_TESTS('added test 200');
SELECT * FROM QUALITY.TEST_RESULT.TEST_RESULT ORDER BY ID DESC LIMIT 10;
```

---

## Running the orchestration procedure

```sql
-- Run all enabled tests
CALL QUALITY.PUBLIC.RUN_ALL_TESTS();

-- Run only metadata compliance tests
CALL QUALITY.PUBLIC.RUN_ALL_TESTS('metadata pass', 'METADATA');

-- Run only business tests
CALL QUALITY.PUBLIC.RUN_ALL_TESTS('business pass', 'BUSINESS');

-- Dry run (count-only, no failure table materialisation)
CALL QUALITY.PUBLIC.RUN_ALL_TESTS('dry run', NULL, TRUE);
```

### What happens per test
1. A `STARTED` row is inserted into `QUALITY.TEST_RESULT.TEST_RESULT`
2. `COUNT(*)` is executed against `QUALITY.PUBLIC.TEST_{ID}` via dynamic SQL
3. If rows > 0 (fail) and not a dry run:
   - A permanent table `QUALITY.TEST_RESULT.TEST_{ID}_FAIL_{STAMP}` is created as  
     `SELECT * FROM QUALITY.PUBLIC.TEST_{ID}` — a point-in-time snapshot
   - An outbox row is inserted into `QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX`
   - If `ON_FAIL_ACTION = 'CALL_PROC'`, the procedure named in `ON_FAIL_PROC_NAME` is called
4. The `TEST_RESULT` row is updated: `END_TIME`, `RUN_TIME`, `STATUS = 'COMPLETED'`, `TEST_PASSED`
5. On any exception: `STATUS = 'ABORTED'`, `TEST_PASSED = FALSE`

### Failure snapshot naming
`QUALITY.TEST_RESULT.TEST_{ID}_FAIL_{STAMP}`  
where `STAMP` uses the Snowflake `TO_CHAR` pattern `'YYYYMMDD_HH24MISS_FF3'`  
(year · month · day _ hour24 · minutes · seconds _ milliseconds) — for example: `TEST_101_FAIL_20260501_224935_123`

These are permanent tables; a separate cleanup process manages retention.

---

## Design principles in action

| Principle | Where applied |
|-----------|---------------|
| **Convention over Configuration** | View names `TEST_{ID}` are derived, never hardcoded |
| **DRY** | `ON_FAIL_ACTION` eliminates per-test `IF` branches in the orchestration proc |
| **Metadata-first** | `TEST` table is the authoritative backlog; a test exists before its view |
| **Non-contentful code** | Orchestration proc contains zero business logic — only reads metadata |
| **Consistent naming** | `SCREAMING_SNAKE_CASE` for all objects; `{ID}_FAIL_{STAMP}` for snapshots |
| **Idempotent scripts** | `CREATE OR REPLACE` everywhere; seed scripts use `DELETE` + `INSERT` |
| **Self-enforcing conventions** | Test 1 flags missing views; Test 2 flags non-conforming views |

---

## Inspecting results

```sql
-- Latest run summary
SELECT TEST_ID, TEST_NAME, STATUS, TEST_PASSED, RUN_TIME AS RUN_TIME_MS
FROM   QUALITY.TEST_RESULT.TEST_RESULT
ORDER  BY ID DESC
LIMIT  10;

-- Pending notifications (SENT_AT IS NULL)
SELECT TEST_NAME, SEVERITY, MESSAGE, FAIL_TABLE_NAME, CREATED_AT
FROM   QUALITY.TEST_RESULT.NOTIFICATION_OUTBOX
WHERE  SENT_AT IS NULL
ORDER  BY ID DESC;

-- All failure snapshot tables
SELECT TABLE_NAME, ROW_COUNT, CREATED
FROM   QUALITY.INFORMATION_SCHEMA.TABLES
WHERE  TABLE_SCHEMA = 'TEST_RESULT'
  AND  TABLE_NAME LIKE 'TEST_%_FAIL_%'
ORDER  BY CREATED DESC;
```

---

## 4-hour session agenda

| Time | Topic | Type |
|------|-------|------|
| 0:00–0:20 | Concepts: metadata-first, CoC, DRY | Presentation |
| 0:20–0:50 | Security & scaffolding (`00_setup/`) | Hands-on |
| 0:50–1:30 | Sample data exploration (`01_sample_data/`) | Hands-on |
| 1:30–2:20 | Test registry (`02_quality_framework/`) | Hands-on |
| 2:20–3:25 | Test views (`03_tests/`) | Hands-on |
| 3:25–4:00 | Orchestration, results, notifications (`04_orchestration/`) | Hands-on |

See [`05_exercises/exercise_prompts.md`](05_exercises/exercise_prompts.md) for all exercise prompts and solutions.

---

## Sample data — expected test outcomes

| Test | Name | Type | Expected result |
|------|------|------|-----------------|
| 1 | Enabled Tests Have Views | METADATA | **PASS** once all `03_tests/` scripts are run |
| 2 | Test Views Expose Contract Columns | METADATA | **PASS** once all views conform to the failure contract |
| 101 | SAP Customer Missing in Salesforce | BUSINESS | **FAIL** — Initech LLC (SAP 1003) has no SF account |
| 102 | No Duplicate SAP-to-SF Mapping | BUSINESS | **FAIL** — Umbrella Co (SAP 1004) maps to A003 and A004 |
| 103 | SAP/Salesforce Account Name Consistent | BUSINESS | **FAIL** — Globex Inc vs Globex Incorporated |

---

## Next steps / extensions

- **Tasks + Streams**: schedule `RUN_ALL_TESTS()` to run on a cron using a Snowflake Task
- **Alerting**: replace `ON_FAIL_STUB` with an External Function that calls AWS SNS / Slack
- **Severity gate**: fail a CI/CD pipeline if any `HIGH` severity tests fail
- **Test domains**: add a `TEST_DOMAIN` table to group tests by subject area (customers, orders, …)
- **Lineage**: add `SOURCE_TABLE` column to `TEST` to power a data quality lineage graph
- **Cleanup procedure**: implement `QUALITY.TEST_RESULT.CLEANUP_FAIL_TABLES(RETAIN_DAYS)` (Bonus Exercise C)
