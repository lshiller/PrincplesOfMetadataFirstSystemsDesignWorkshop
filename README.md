# Principles of Metadata-First Systems Design Workshop

Artifacts used to build a principled Metadata-First foundation on the [Snowflake](https://www.snowflake.com/) platform.

---

## Overview

This workshop teaches participants how to design data systems where **metadata drives behavior** rather than hard-coded logic. By leveraging Snowflake's rich metadata capabilities — Object Tags, Dynamic Data Masking, Row Access Policies, INFORMATION_SCHEMA, and ACCOUNT_USAGE — you will build a governance-first, self-describing data platform.

### Core Principles Covered

1. **Discover before you build** — query existing metadata before writing new DDL/DML.
2. **Tag everything** — attach business-context tags to every sensitive object at creation time.
3. **Policies follow tags** — security and masking policies bind to tags, not to individual columns.
4. **Governance as code** — all metadata rules live in version-controlled SQL alongside the data model.
5. **Observe continuously** — use ACCOUNT_USAGE views to audit, alert, and evolve the system.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Snowflake account | Trial or production; ACCOUNTADMIN or SYSADMIN + SECURITYADMIN recommended |
| Snowflake worksheet or SnowSQL CLI | All exercises run as SQL scripts |
| Git | To clone this repository |

---

## Repository Structure

```
.
├── README.md                          ← You are here
├── setup/
│   ├── 00_environment_setup.sql       ← Warehouse, database, roles, schemas
│   └── 01_sample_data.sql             ← Sample tables & realistic data (retail + HR)
├── exercises/
│   ├── 01_information_schema_exploration.sql  ← Mining INFORMATION_SCHEMA & ACCOUNT_USAGE
│   ├── 02_object_tagging.sql                  ← Creating and applying Object Tags
│   ├── 03_dynamic_data_masking.sql            ← Tag-driven masking policies
│   ├── 04_row_access_policies.sql             ← Row-level security via metadata
│   ├── 05_data_classification.sql             ← Automated + manual data classification
│   └── 06_metadata_driven_architecture.sql    ← Metadata-driven pipelines & governance
└── teardown/
    └── teardown.sql                   ← Remove all workshop objects
```

---

## Workshop Agenda (approx. 4 hours)

| # | Module | Time |
|---|---|---|
| 0 | Environment setup & sample data | 20 min |
| 1 | Exploring Snowflake metadata (INFORMATION_SCHEMA / ACCOUNT_USAGE) | 30 min |
| 2 | Object Tags — classify your data landscape | 40 min |
| 3 | Dynamic Data Masking driven by tags | 40 min |
| 4 | Row Access Policies & metadata-driven row filtering | 40 min |
| 5 | Automated data classification & sensitive-data discovery | 30 min |
| 6 | Metadata-driven architecture patterns | 40 min |
| — | Wrap-up, Q&A, teardown | 20 min |

---

## Getting Started

1. Clone this repository.
2. Open a Snowflake worksheet (or SnowSQL session) and execute the scripts in the order shown above, starting with `setup/00_environment_setup.sql`.
3. Follow the inline comments in each exercise file — they explain the "why" as well as the "how".
4. When finished, run `teardown/teardown.sql` to remove all workshop objects.

---

## License

See [LICENSE](LICENSE).
