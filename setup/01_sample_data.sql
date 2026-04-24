/*
================================================================================
  Workshop: Principles of Metadata-First Systems Design
  Script  : 01_sample_data.sql
  Purpose : Create realistic sample tables in the RAW and CURATED schemas and
            populate them with data that will be used throughout every exercise.

  Domain  : A fictional retailer ("NorthStar Retail") and its HR department.
            Data includes customer PII, transaction records, product catalog,
            and employee information — giving us plenty of sensitive columns to
            classify, mask, and govern.

  Run as  : DATA_ENGINEER (or SYSADMIN / ACCOUNTADMIN).
  Requires: setup/00_environment_setup.sql must have been executed first.
================================================================================
*/

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WORKSHOP_WH;
USE DATABASE METADATA_WORKSHOP_DB;


-- ============================================================
-- 1.  RAW Layer — tables as they arrive from source systems
--     No tags or policies yet; that happens in CURATED.
-- ============================================================
USE SCHEMA RAW;


-- ── Customers ────────────────────────────────────────────────
CREATE OR REPLACE TABLE RAW.CUSTOMERS (
    CUSTOMER_ID       NUMBER        NOT NULL,
    FIRST_NAME        VARCHAR(100)  NOT NULL,
    LAST_NAME         VARCHAR(100)  NOT NULL,
    EMAIL             VARCHAR(255)  NOT NULL,
    PHONE             VARCHAR(30),
    DATE_OF_BIRTH     DATE,
    SSN               VARCHAR(20),          -- Social Security Number (highly sensitive)
    STREET_ADDRESS    VARCHAR(255),
    CITY              VARCHAR(100),
    STATE_CODE        VARCHAR(2),
    ZIP_CODE          VARCHAR(10),
    COUNTRY_CODE      VARCHAR(3)    DEFAULT 'USA',
    LOYALTY_TIER      VARCHAR(20),          -- BRONZE | SILVER | GOLD | PLATINUM
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.CUSTOMERS VALUES
    (1001, 'Alice',   'Nguyen',     'alice.nguyen@example.com',   '555-0101', '1985-03-12', '123-45-6789', '1 Maple St',      'Springfield', 'IL', '62701', 'USA', 'GOLD',     CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1002, 'Bob',     'Martinez',   'bob.martinez@example.com',   '555-0102', '1990-07-25', '234-56-7890', '22 Oak Ave',      'Portland',    'OR', '97201', 'USA', 'SILVER',   CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1003, 'Carol',   'Okonkwo',    'carol.okonkwo@example.com',  '555-0103', '1978-11-08', '345-67-8901', '333 Pine Rd',     'Austin',      'TX', '78701', 'USA', 'PLATINUM', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1004, 'David',   'Kim',        'david.kim@example.com',      '555-0104', '1995-02-14', '456-78-9012', '44 Elm Blvd',     'Seattle',     'WA', '98101', 'USA', 'BRONZE',   CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1005, 'Eva',     'Rodriguez',  'eva.rodriguez@example.com',  '555-0105', '1982-09-30', '567-89-0123', '555 Birch Ln',    'Miami',       'FL', '33101', 'USA', 'GOLD',     CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1006, 'Frank',   'Thompson',   'frank.thompson@example.com', '555-0106', '1968-06-17', '678-90-1234', '666 Cedar Dr',    'Boston',      'MA', '02101', 'USA', 'SILVER',   CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1007, 'Grace',   'Patel',      'grace.patel@example.com',    '555-0107', '2000-12-01', '789-01-2345', '7 Spruce Ct',     'Denver',      'CO', '80201', 'USA', 'BRONZE',   CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1008, 'Henry',   'Johansson',  'henry.j@example.com',        '555-0108', '1975-04-22', '890-12-3456', '88 Walnut Way',   'Atlanta',     'GA', '30301', 'USA', 'PLATINUM', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1009, 'Irene',   'Dubois',     'irene.dubois@example.com',   '555-0109', '1993-08-05', '901-23-4567', '9 Ash Circle',    'Chicago',     'IL', '60601', 'USA', 'GOLD',     CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
    (1010, 'James',   'Chen',       'james.chen@example.com',     '555-0110', '1988-01-19', '012-34-5678', '10 Hickory Pass', 'Phoenix',     'AZ', '85001', 'USA', 'SILVER',   CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());


-- ── Products ─────────────────────────────────────────────────
CREATE OR REPLACE TABLE RAW.PRODUCTS (
    PRODUCT_ID        NUMBER        NOT NULL,
    SKU               VARCHAR(50)   NOT NULL,
    PRODUCT_NAME      VARCHAR(255)  NOT NULL,
    CATEGORY          VARCHAR(100),
    SUBCATEGORY       VARCHAR(100),
    UNIT_PRICE        NUMBER(10, 2) NOT NULL,
    COST              NUMBER(10, 2),
    SUPPLIER_ID       NUMBER,
    ACTIVE            BOOLEAN       DEFAULT TRUE,
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.PRODUCTS VALUES
    (1, 'SKU-001', 'Wireless Mouse',       'Electronics',  'Peripherals',  29.99,  12.50, 201, TRUE, CURRENT_TIMESTAMP()),
    (2, 'SKU-002', 'Mechanical Keyboard',  'Electronics',  'Peripherals', 109.99,  45.00, 201, TRUE, CURRENT_TIMESTAMP()),
    (3, 'SKU-003', 'USB-C Hub',            'Electronics',  'Cables',       49.99,  18.75, 202, TRUE, CURRENT_TIMESTAMP()),
    (4, 'SKU-004', 'Laptop Stand',         'Accessories',  'Desk',         34.99,  11.00, 203, TRUE, CURRENT_TIMESTAMP()),
    (5, 'SKU-005', 'Noise-Cancelling Headphones', 'Electronics', 'Audio', 249.99, 95.00, 201, TRUE, CURRENT_TIMESTAMP()),
    (6, 'SKU-006', 'Ergonomic Chair',      'Furniture',    'Seating',     499.99, 210.00, 204, TRUE, CURRENT_TIMESTAMP()),
    (7, 'SKU-007', 'Standing Desk',        'Furniture',    'Desks',       799.99, 320.00, 204, TRUE, CURRENT_TIMESTAMP()),
    (8, 'SKU-008', 'Webcam HD',            'Electronics',  'Peripherals',  79.99,  28.00, 202, TRUE, CURRENT_TIMESTAMP()),
    (9, 'SKU-009', 'Monitor 27"',          'Electronics',  'Displays',    399.99, 155.00, 205, TRUE, CURRENT_TIMESTAMP()),
   (10, 'SKU-010', 'Cable Management Kit', 'Accessories',  'Desk',         19.99,   6.50, 203, TRUE, CURRENT_TIMESTAMP());


-- ── Orders ───────────────────────────────────────────────────
CREATE OR REPLACE TABLE RAW.ORDERS (
    ORDER_ID          NUMBER        NOT NULL,
    CUSTOMER_ID       NUMBER        NOT NULL,
    ORDER_DATE        DATE          NOT NULL,
    STATUS            VARCHAR(30),          -- PENDING | SHIPPED | DELIVERED | CANCELLED
    PAYMENT_METHOD    VARCHAR(50),
    CREDIT_CARD_LAST4 VARCHAR(4),           -- Sensitive: last 4 digits of payment card
    SHIPPING_ADDRESS  VARCHAR(500),
    TOTAL_AMOUNT      NUMBER(12, 2),
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.ORDERS VALUES
    (5001, 1001, '2024-01-10', 'DELIVERED', 'CREDIT_CARD', '4242', '1 Maple St, Springfield IL 62701', 139.98, CURRENT_TIMESTAMP()),
    (5002, 1002, '2024-01-12', 'DELIVERED', 'PAYPAL',      NULL,   '22 Oak Ave, Portland OR 97201',    109.99, CURRENT_TIMESTAMP()),
    (5003, 1003, '2024-01-15', 'SHIPPED',   'CREDIT_CARD', '1234', '333 Pine Rd, Austin TX 78701',     749.98, CURRENT_TIMESTAMP()),
    (5004, 1004, '2024-01-20', 'PENDING',   'DEBIT_CARD',  '5678', '44 Elm Blvd, Seattle WA 98101',     49.99, CURRENT_TIMESTAMP()),
    (5005, 1005, '2024-02-01', 'DELIVERED', 'CREDIT_CARD', '9999', '555 Birch Ln, Miami FL 33101',     279.98, CURRENT_TIMESTAMP()),
    (5006, 1001, '2024-02-14', 'CANCELLED', 'CREDIT_CARD', '4242', '1 Maple St, Springfield IL 62701',  79.99, CURRENT_TIMESTAMP()),
    (5007, 1006, '2024-02-20', 'DELIVERED', 'CREDIT_CARD', '3333', '666 Cedar Dr, Boston MA 02101',    499.99, CURRENT_TIMESTAMP()),
    (5008, 1007, '2024-03-05', 'SHIPPED',   'PAYPAL',      NULL,   '7 Spruce Ct, Denver CO 80201',      29.99, CURRENT_TIMESTAMP()),
    (5009, 1008, '2024-03-10', 'DELIVERED', 'CREDIT_CARD', '7777', '88 Walnut Way, Atlanta GA 30301',  399.99, CURRENT_TIMESTAMP()),
    (5010, 1009, '2024-03-15', 'DELIVERED', 'DEBIT_CARD',  '2222', '9 Ash Circle, Chicago IL 60601',   139.98, CURRENT_TIMESTAMP());


-- ── Order Line Items ─────────────────────────────────────────
CREATE OR REPLACE TABLE RAW.ORDER_ITEMS (
    ORDER_ITEM_ID     NUMBER        NOT NULL,
    ORDER_ID          NUMBER        NOT NULL,
    PRODUCT_ID        NUMBER        NOT NULL,
    QUANTITY          NUMBER        NOT NULL,
    UNIT_PRICE        NUMBER(10, 2) NOT NULL,
    LINE_TOTAL        NUMBER(12, 2) NOT NULL,
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.ORDER_ITEMS VALUES
    (1, 5001, 1,  1,  29.99,  29.99, CURRENT_TIMESTAMP()),
    (2, 5001, 2,  1, 109.99, 109.99, CURRENT_TIMESTAMP()),
    (3, 5002, 2,  1, 109.99, 109.99, CURRENT_TIMESTAMP()),
    (4, 5003, 6,  1, 499.99, 499.99, CURRENT_TIMESTAMP()),
    (5, 5003, 4,  2,  34.99,  69.98, CURRENT_TIMESTAMP()),
    (6, 5003, 10, 1,  19.99,  19.99, CURRENT_TIMESTAMP()),
    (7, 5004, 3,  1,  49.99,  49.99, CURRENT_TIMESTAMP()),
    (8, 5005, 5,  1, 249.99, 249.99, CURRENT_TIMESTAMP()),
    (9, 5005, 10, 1,  19.99,  19.99, CURRENT_TIMESTAMP()),
   (10, 5006, 8,  1,  79.99,  79.99, CURRENT_TIMESTAMP()),
   (11, 5007, 6,  1, 499.99, 499.99, CURRENT_TIMESTAMP()),
   (12, 5008, 1,  1,  29.99,  29.99, CURRENT_TIMESTAMP()),
   (13, 5009, 9,  1, 399.99, 399.99, CURRENT_TIMESTAMP()),
   (14, 5010, 1,  1,  29.99,  29.99, CURRENT_TIMESTAMP()),
   (15, 5010, 2,  1, 109.99, 109.99, CURRENT_TIMESTAMP());


-- ── Employees (HR) ───────────────────────────────────────────
CREATE OR REPLACE TABLE RAW.EMPLOYEES (
    EMPLOYEE_ID       NUMBER        NOT NULL,
    FIRST_NAME        VARCHAR(100)  NOT NULL,
    LAST_NAME         VARCHAR(100)  NOT NULL,
    EMAIL             VARCHAR(255)  NOT NULL,
    PHONE             VARCHAR(30),
    DATE_OF_BIRTH     DATE,
    SSN               VARCHAR(20),
    DEPARTMENT        VARCHAR(100),
    JOB_TITLE         VARCHAR(150),
    MANAGER_ID        NUMBER,
    ANNUAL_SALARY     NUMBER(12, 2),        -- Sensitive: salary information
    HIRE_DATE         DATE,
    TERMINATION_DATE  DATE,
    ACTIVE            BOOLEAN       DEFAULT TRUE,
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.EMPLOYEES VALUES
    (2001, 'Sarah',  'Lin',       'sarah.lin@northstar.com',      '555-2001', '1980-05-14', '111-11-1111', 'Engineering',   'VP Engineering',          NULL, 180000.00, '2018-01-15', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2002, 'Marcus', 'Bell',      'marcus.bell@northstar.com',    '555-2002', '1987-09-03', '222-22-2222', 'Engineering',   'Senior Data Engineer',    2001,  120000.00, '2019-06-01', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2003, 'Nina',   'Osei',      'nina.osei@northstar.com',      '555-2003', '1992-03-27', '333-33-3333', 'Analytics',     'Data Analyst',            2001,   90000.00, '2021-03-10', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2004, 'Lucas',  'Ferreira',  'lucas.f@northstar.com',        '555-2004', '1985-11-19', '444-44-4444', 'Analytics',     'Senior Data Analyst',     2001,  105000.00, '2020-07-20', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2005, 'Priya',  'Sharma',    'priya.sharma@northstar.com',   '555-2005', '1990-07-08', '555-55-5555', 'Governance',    'Data Governor',           2001,   95000.00, '2022-01-01', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2006, 'Owen',   'Wright',    'owen.wright@northstar.com',    '555-2006', '1978-02-28', '666-66-6666', 'Compliance',    'Compliance Officer',      2001,  115000.00, '2017-09-12', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2007, 'Aisha',  'Mohammed',  'aisha.m@northstar.com',        '555-2007', '1995-06-15', '777-77-7777', 'Engineering',   'Data Engineer',           2002,   95000.00, '2023-02-14', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2008, 'Tom',    'Nakamura',  'tom.nakamura@northstar.com',   '555-2008', '1983-10-31', '888-88-8888', 'HR',            'HR Business Partner',     NULL,   85000.00, '2016-04-05', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2009, 'Leila',  'Hassan',    'leila.hassan@northstar.com',   '555-2009', '1997-01-22', '999-99-9999', 'Engineering',   'Junior Data Engineer',    2002,   78000.00, '2024-03-01', NULL,         TRUE, CURRENT_TIMESTAMP()),
    (2010, 'Ryan',   'Kowalski',  'ryan.k@northstar.com',         '555-2010', '1975-08-09', '000-00-0001', 'Engineering',   'Principal Data Architect',2001,  155000.00, '2015-11-30', '2024-01-31', FALSE, CURRENT_TIMESTAMP());


-- ============================================================
-- 2.  CURATED Layer — mirror of RAW, tagged and ready for
--     exercises 02-06.  We create these as COPY of RAW so
--     participants start from a clean state.
-- ============================================================
USE SCHEMA CURATED;

CREATE OR REPLACE TABLE CURATED.CUSTOMERS   AS SELECT * FROM RAW.CUSTOMERS;
CREATE OR REPLACE TABLE CURATED.PRODUCTS    AS SELECT * FROM RAW.PRODUCTS;
CREATE OR REPLACE TABLE CURATED.ORDERS      AS SELECT * FROM RAW.ORDERS;
CREATE OR REPLACE TABLE CURATED.ORDER_ITEMS AS SELECT * FROM RAW.ORDER_ITEMS;
CREATE OR REPLACE TABLE CURATED.EMPLOYEES   AS SELECT * FROM RAW.EMPLOYEES;

-- Grant SELECT on curated tables to analyst and governor roles
GRANT SELECT ON ALL TABLES IN SCHEMA METADATA_WORKSHOP_DB.CURATED TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA METADATA_WORKSHOP_DB.CURATED TO ROLE DATA_GOVERNOR;
GRANT SELECT ON ALL TABLES IN SCHEMA METADATA_WORKSHOP_DB.CURATED TO ROLE PRIVILEGED_VIEWER;


-- ============================================================
-- 3.  GOVERNANCE — a lookup table used by row access policies
-- ============================================================
USE SCHEMA GOVERNANCE;

-- Maps Snowflake role names to the data regions they are allowed to see
CREATE OR REPLACE TABLE GOVERNANCE.ROLE_REGION_MAPPING (
    SNOWFLAKE_ROLE  VARCHAR(100)  NOT NULL,
    ALLOWED_REGION  VARCHAR(10)   NOT NULL,   -- e.g. 'IL', 'OR', 'ALL'
    NOTES           VARCHAR(500)
);

INSERT INTO GOVERNANCE.ROLE_REGION_MAPPING VALUES
    ('DATA_ENGINEER',    'ALL', 'Engineers see all regions'),
    ('DATA_ANALYST',     'IL',  'Default analysts only see Illinois data'),
    ('DATA_ANALYST',     'OR',  'Default analysts also see Oregon data'),
    ('PRIVILEGED_VIEWER','ALL', 'Privileged viewers see all regions');

GRANT USAGE  ON SCHEMA METADATA_WORKSHOP_DB.GOVERNANCE              TO ROLE DATA_ANALYST;
GRANT SELECT ON TABLE  METADATA_WORKSHOP_DB.GOVERNANCE.ROLE_REGION_MAPPING TO ROLE DATA_ANALYST;
GRANT SELECT ON TABLE  METADATA_WORKSHOP_DB.GOVERNANCE.ROLE_REGION_MAPPING TO ROLE DATA_GOVERNOR;
GRANT SELECT ON TABLE  METADATA_WORKSHOP_DB.GOVERNANCE.ROLE_REGION_MAPPING TO ROLE PRIVILEGED_VIEWER;


-- ============================================================
-- 4.  Verification
-- ============================================================
USE SCHEMA RAW;
SELECT 'RAW.CUSTOMERS'   AS table_name, COUNT(*) AS row_count FROM RAW.CUSTOMERS
UNION ALL
SELECT 'RAW.PRODUCTS',   COUNT(*) FROM RAW.PRODUCTS
UNION ALL
SELECT 'RAW.ORDERS',     COUNT(*) FROM RAW.ORDERS
UNION ALL
SELECT 'RAW.ORDER_ITEMS',COUNT(*) FROM RAW.ORDER_ITEMS
UNION ALL
SELECT 'RAW.EMPLOYEES',  COUNT(*) FROM RAW.EMPLOYEES
ORDER BY 1;

-- ============================================================
-- Next step: Run exercises/01_information_schema_exploration.sql
-- ============================================================
