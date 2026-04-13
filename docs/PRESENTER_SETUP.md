# Presenter Setup Guide

Everything you need to run the demo. Read this first.

**Time to get ready:** ~20 minutes (if Snowflake access is already granted)
**Contact for access:** Hicham Babahmed

---

## What You Need

| Tool | Details |
|------|---------|
| Snowflake account | URL: `https://app.snowflake.com/cmvgrnf/zna84829` · Role: `TRANSFORMER` · Warehouse: `DBT_DEV_WH` |
| dbt Cloud | `cloud.getdbt.com` — ask Hicham to add you to the project |
| Streamlit app | Deployed in Snowflake — link below |

---

## Step 1 — Get Snowflake Access

Ask Hicham to run:
```sql
GRANT ROLE TRANSFORMER TO USER <your_snowflake_username>;
```

Then verify you can see the data:
```sql
USE ROLE TRANSFORMER;
USE WAREHOUSE DBT_DEV_WH;
USE DATABASE HICHAMB_FIVETRAN_DEMO;

SELECT COUNT(*) FROM RETAIL_DEMO_RETAIL.SALES_ORDERS;   -- 4,074
SELECT COUNT(*) FROM RETAIL_DEMO_RETAIL.CUSTOMERS;       -- 28,813
SELECT COUNT(*) FROM MARTS.DIM_CUSTOMERS;                -- significantly less (SCD2 resolved)
```

If `MARTS.DIM_CUSTOMERS` doesn't exist yet, Hicham needs to run `dbt build` first.

---

## Step 2 — Open the Streamlit App

In Snowsight → **Projects → Streamlit** → `retail_cortex_chat`

This is the **main demo tool**. It has two modes:
- **Raw Data (Fivetran)** — red badge — what AI gets wrong
- **dbt Marts (Governed)** — green badge — what AI gets right

Keep this open for Acts 1 and 3.

---

## Step 3 — Get dbt Cloud Access

Ask Hicham to invite you to the **"Retail Demo"** dbt Cloud project.

Once in, familiarise yourself with:
- **Explore** tab → the DAG (you'll walk this in Act 2)
- **Jobs** → most recent run should be green
- Open `models/intermediate/int_current_customers.sql` — you'll reference this in Act 2

---

## Step 4 — Prepare Your Browser Tabs

Before presenting, have these open and ready:

| Tab | What it is | Used in |
|-----|-----------|---------|
| Streamlit app (Raw Data mode) | Cortex Analyst chat — raw | Act 1 |
| dbt Cloud Explorer (DAG view) | Lineage graph | Act 2 |
| Streamlit app (dbt Marts mode) | Cortex Analyst chat — governed | Act 3 |

Pre-type (but don't send) in tab 1: **"What was our total revenue last month?"**

---

## The Demo (20 min)

### Act 1 — Raw Data + AI = Chaos (5 min)

Open **Streamlit → Raw Data mode**.

Ask these three questions in order. Watch what breaks.

**Q1: "What was our total revenue last month?"**
- `SALES_ORDERS` has no revenue column — `ORDERED_PRODUCTS` is a raw JSON text blob
- Cortex returns null, a wrong number, or fails to generate SQL
- **Say:** *"There's no revenue column in the raw table. ORDERED_PRODUCTS is a JSON blob the AI can't parse. It either guesses or gives up."*

**Q2: "How many customers do we have by loyalty tier?"**
- `LOYALTY_SEGMENT` is stored as raw numbers (1, 2, 3, 4) — no label
- `CUSTOMERS` is SCD2 — multiple rows per customer inflate all counts
- **Say:** *"Two problems. The loyalty segment is a number — not 'Gold'. And the customer table has multiple rows per customer because it tracks history. The AI is counting versions of customers, not customers."*

**Q3: "Which region has the most orders in the last 6 months?"**
- `ORDER_DATETIME` is a Unix epoch NUMBER — not a DATE
- Time filters produce garbage results
- **Say:** *"ORDER_DATETIME is stored as a Unix epoch — a big number. The AI doesn't know it's a date. Any time filter here is meaningless."*

**Pause. Land the point:**
> *"The data pipeline is perfect. Fivetran moved every row without losing a single record. But moved data is not analytics-ready data. The AI is doing its best — and failing because the foundation isn't there."*

---

### Act 2 — dbt Brings Order (10 min)

Switch to **dbt Cloud Explorer**.

**Walk the DAG top to bottom:**

> *"Same Snowflake data — transformed in layers."*

**Staging layer** (`stg_*` models):
> *"Six staging models — one per source table. Key work: `stg_sales_orders` converts ORDER_DATETIME from epoch to a real date, and runs TRY_PARSE_JSON on ORDERED_PRODUCTS. `stg_customers` flags which rows are current in the SCD2 table."*

**`int_current_customers`** (click to open):
> *"This is the most important model. 28,813 rows in the raw table. After this model: one row per customer. SCD2 resolved. And LOYALTY_SEGMENT 3 becomes 'Gold' — joined from the lookup table."*

**`int_sales_order_lines`**:
> *"This explodes the ORDERED_PRODUCTS JSON — one row per line item — and extracts quantity and unit price. Revenue doesn't exist in the source. dbt creates it."*

**Open `_core_models.yml`** (model contracts):
> *"Contracts enforce the schema. Tests validate: customer IDs are unique, revenue is non-negative, every order has a valid customer. If any of this breaks, `dbt build` fails before AI ever sees the data."*

**Semantic Layer** (if time allows):
> *"Metrics defined once in code: total_b2c_revenue, avg_order_value, b2b_cancellation_rate. Version controlled. Serving Tableau, Hex, and Cortex consistently."*

---

### Act 3 — AI + dbt = Trust (5 min)

Switch to **Streamlit → dbt Marts mode**.

Ask the **exact same three questions**.

**Q1: "What was our total revenue last month?"**
- Returns a dollar amount — `total_revenue` from `fct_sales_orders`
- **Say:** *"Revenue is now a first-class column — computed by dbt from parsed line items."*

**Q2: "How many customers do we have by loyalty tier?"**
- Returns: Gold / Platinum / Silver / Bronze with correct counts
- **Say:** *"Readable tier names. Correct counts — because the SCD2 table has been resolved to one row per customer."*

**Q3: "Which region has the most orders in the last 6 months?"**
- Correct time filter because `order_date` is a proper DATE
- **Say:** *"Time filter works because the epoch was converted in staging."*

**Close:**
> *"Same Cortex Analyst. Same data in Snowflake. Dramatically different answers. The difference is the layer between raw ingestion and AI consumption — that's dbt.*
>
> *Fivetran moved the data. Snowflake stores it. But without dbt in the middle, AI gets the wrong answer every time. dbt is the trust layer."*

---

## Likely Questions + Answers

**"Can Cortex Analyst parse the JSON itself?"**
> *"It can try — but it doesn't know your business rules. Which fields are revenue? What about cancelled orders? What if the JSON format changes next week? dbt encodes those decisions in version-controlled, tested SQL."*

**"Why is ORDER_DATETIME stored as a number?"**
> *"Common in source systems built for transactions — Unix epoch is efficient to store and index. The source is built for operations, not analytics. That's why the transformation layer exists."*

**"Doesn't dbt add complexity?"**
> *"SQL transformations were happening anyway — in BI tools, in stored procedures, in notebooks. dbt makes them visible, tested, and version-controlled. It organises complexity that already exists."*

**"What about Snowflake semantic views — can't they do the same thing?"**
> *"Snowflake semantic views describe tables — they're documentation for Cortex. dbt Semantic Layer defines and enforces metrics, and works on Databricks, BigQuery, and Redshift too. One metric definition, everywhere."*

---

## Emergency Fallback

If Streamlit or Cortex Analyst is down, you can demonstrate Act 1 vs Act 3 directly in Snowflake Worksheets:

**Act 1 — Show the raw problem:**
```sql
-- No revenue column — ORDERED_PRODUCTS is opaque text
SELECT id, customer_id, ordered_products, order_datetime
FROM HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.SALES_ORDERS
LIMIT 5;

-- SCD2 — duplicate customer_ids
SELECT customer_id, COUNT(*) AS versions
FROM HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.CUSTOMERS
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY 2 DESC
LIMIT 5;
```

**Act 3 — Show the governed result:**
```sql
-- Revenue exists as a clean column
SELECT order_id, order_date, total_revenue, has_promo
FROM HICHAMB_FIVETRAN_DEMO.MARTS.FCT_SALES_ORDERS
ORDER BY order_date DESC
LIMIT 10;

-- One row per customer, readable loyalty tier
SELECT customer_name, region, loyalty_segment_description, customer_value_segment
FROM HICHAMB_FIVETRAN_DEMO.MARTS.DIM_CUSTOMERS
ORDER BY units_purchased DESC
LIMIT 10;
```

---

## Key Numbers to Know

| Fact | Value |
|------|-------|
| Raw CUSTOMERS rows | 28,813 (includes SCD2 history) |
| Unique customers after SCD2 resolution | check `SELECT COUNT(*) FROM MARTS.DIM_CUSTOMERS` |
| Loyalty tiers | Bronze / Silver / Gold / Platinum (4 segments) |
| B2C orders | 4,074 |
| B2B orders | 2,000 |
| B2B accounts | 100 |
| Support tickets | 150 |
