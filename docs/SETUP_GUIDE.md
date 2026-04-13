# Setup Guide

Step-by-step instructions to get the demo running. Estimated time: **30–60 minutes** (data is already in Snowflake via Fivetran).

---

## Prerequisites

| Tool | Notes |
|------|-------|
| Snowflake account | Access to `HICHAMB_FIVETRAN_DEMO` with `TRANSFORMER` role |
| dbt Cloud account | Team or Enterprise plan (for hosted Semantic Layer) |
| Git | To clone the repo |

The Fivetran connector is already running — `HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL` has all 6 tables synced.

---

## Step 1 — Clone the Repo

```bash
git clone https://github.com/YOUR_ORG/fretwork-guitars-dbt.git
cd fretwork-guitars-dbt
```

---

## Step 2 — Snowflake Roles & Grants

Run `snowflake/00_setup_warehouse.sql` in Snowflake Worksheets as SYSADMIN.

This creates:
- A `MARTS` schema for dbt output (if not already present)
- Grants for the `TRANSFORMER` role to read `RETAIL_DEMO_RETAIL` and write to `MARTS`
- Grants for Cortex Analyst access (`SNOWFLAKE.CORTEX_USER` privilege)

**Verify access:**
```sql
USE ROLE TRANSFORMER;
USE WAREHOUSE DBT_DEV_WH;
SELECT COUNT(*) FROM HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.SALES_ORDERS; -- 4,074
SELECT COUNT(*) FROM HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.CUSTOMERS;    -- 28,813
```

---

## Step 3 — dbt Cloud Project Setup

1. Log in to [cloud.getdbt.com](https://cloud.getdbt.com)
2. Create a new project: **"Retail Demo"**
3. Connect to Snowflake:

   | Setting | Value |
   |---------|-------|
   | Account | Your Snowflake account identifier |
   | Database | `HICHAMB_FIVETRAN_DEMO` |
   | Warehouse | `DBT_DEV_WH` |
   | Role | `TRANSFORMER` |
   | Schema | `DEV_<yourname>` (development target) |

4. Connect this GitHub repo
5. In **Project settings**, set the dbt version to **1.8+**

---

## Step 4 — Install Packages & Verify Compilation

In the dbt Cloud IDE or CLI:

```bash
dbt deps      # installs dbt_utils, dbt_expectations

dbt compile   # should complete with no errors
```

If you see "source not found" errors, verify `vars` in `dbt_project.yml`:
```yaml
vars:
  retail_database: HICHAMB_FIVETRAN_DEMO
  retail_schema:   RETAIL_DEMO_RETAIL
```

---

## Step 5 — Run dbt Build

```bash
dbt build
# Runs all models + tests in dependency order
```

**Expected output:**
```
staging/retail/   → 6 view models (stg_*)
intermediate/     → 3 ephemeral models (int_*)
marts/core/       → dim_customers, dim_b2b_customers, fct_sales_orders
marts/finance/    → fct_b2b_orders
semantic/         → metricflow_time_spine
tests             → all passing
```

**Spot-check results:**
```sql
USE SCHEMA HICHAMB_FIVETRAN_DEMO.MARTS;

SELECT COUNT(DISTINCT customer_id) FROM dim_customers;   -- should be << 28,813 (SCD2 resolved)
SELECT COUNT(*) FROM fct_sales_orders;                   -- ~4,074
SELECT SUM(total_revenue) FROM fct_sales_orders;         -- non-null dollar amount

-- Verify loyalty segment join worked
SELECT loyalty_segment_description, COUNT(*) AS customers
FROM dim_customers
GROUP BY 1
ORDER BY 2 DESC;
-- Should show: Bronze / Silver / Gold / Platinum (not 1/2/3/4)
```

---

## Step 6 — dbt Semantic Layer

1. In dbt Cloud → **Account Settings → Integrations → Semantic Layer**
2. Enable it for this project
3. Note the JDBC endpoint URL

**Test a metric:**
```bash
dbt sl query --metrics total_b2c_revenue --group-by metric_time__month
# Should return monthly revenue figures
```

---

## Step 7 — Cortex Analyst Semantic Views

Run both files in Snowflake Worksheets as SYSADMIN or TRANSFORMER:

```sql
-- Act 1: raw data (chaos) — intentionally minimal
-- Run: snowflake/01_cortex_raw_semantic_view.sql

-- Act 3: dbt marts (trust) — rich descriptions and measures
-- Run: snowflake/02_cortex_dbt_semantic_view.sql
```

**Verify:**
```sql
SHOW SEMANTIC VIEWS IN DATABASE HICHAMB_FIVETRAN_DEMO;
-- Should list: cortex_retail_raw_sv, cortex_retail_dbt_sv
```

If `CREATE SEMANTIC VIEW` is not available in your edition, use the legacy YAML fallback:
```sql
-- Upload to a Snowflake stage, then reference in Cortex Analyst calls
PUT file://snowflake/01_cortex_raw_semantic_model.yaml @MY_STAGE auto_compress=false;
PUT file://snowflake/02_cortex_dbt_semantic_model.yaml @MY_STAGE auto_compress=false;
```

---

## Step 8 — Streamlit in Snowflake App

1. Run `streamlit/setup_sis_app.sql` in Snowflake Worksheets
2. Upload the app:
   ```sql
   PUT file://streamlit/cortex_analyst_chat.py @HICHAMB_FIVETRAN_DEMO.MARTS.streamlit_stage
       auto_compress=false overwrite=true;
   ```
3. In Snowsight → **Projects → Streamlit** → open `retail_cortex_chat`

**Test the toggle:**
- Select "Raw Data" mode → ask "What was our total revenue last month?" → should fail or return a suspicious number
- Select "dbt Marts" mode → same question → should return a clean dollar amount

---

## Verification Checklist

Before the demo:

- [ ] `dbt build` completes with 0 errors, 0 test failures
- [ ] `SELECT COUNT(DISTINCT customer_id) FROM dim_customers` returns a number significantly less than 28,813
- [ ] `SELECT loyalty_segment_description, COUNT(*) FROM dim_customers GROUP BY 1` shows readable tier names
- [ ] `SELECT SUM(total_revenue) FROM fct_sales_orders` returns a non-zero value
- [ ] Both Cortex Analyst semantic views exist (`SHOW SEMANTIC VIEWS`)
- [ ] Streamlit app opens in both modes and returns different answers to the same question

---

## Troubleshooting

**`dbt build` fails on stg_sales_orders — TRY_PARSE_JSON error**
→ Check that `ORDERED_PRODUCTS` column exists and contains text. Run:
```sql
SELECT ordered_products FROM HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.SALES_ORDERS LIMIT 5;
```

**dim_customers has the same count as raw CUSTOMERS (28,813)**
→ The SCD2 filter may not be working. Check `stg_customers.sql` — the `is_current` logic
assumes `VALID_TO = 0` means current. Run this to verify:
```sql
SELECT valid_to, COUNT(*) FROM HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.CUSTOMERS GROUP BY 1 ORDER BY 2 DESC;
```
Adjust the condition in `stg_customers.sql` if `VALID_TO` uses a different sentinel value.

**Cortex Analyst returns "I don't have enough information"**
→ Add more synonyms or verified_queries to `02_cortex_dbt_semantic_model.yaml` and re-upload.

**Streamlit app authentication error**
→ Verify `GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE TRANSFORMER` was run.
