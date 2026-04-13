# dbt Mesh — Harmony Music Retail Demo

A multi-project **dbt Mesh** architecture demonstrating how independent teams (platform, marketing, finance) collaborate through governed data contracts and cross-project references.

Built for a joint demo with Snowflake and Fivetran teams.
**Data source:** Retail dataset (Google Cloud SQL / PostgreSQL -> Fivetran -> Snowflake).

## The Demo in One Sentence

Snowflake Cortex Analyst gives wrong answers on raw Fivetran data, and correct answers on dbt-governed marts — same AI, same questions, dramatically different results. The Mesh layer shows how downstream teams consume trusted data without duplicating logic.

---

## dbt Mesh Architecture

```
Google Cloud SQL (PostgreSQL)
  retail schema (6 tables)
         |
    Fivetran connector
         |
HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL  <-- raw tables
         |
   ======|============================== dbt Mesh ===============================
   |                    |                              |                         |
   |   PLATFORM         |   MARKETING                 |   FINANCE               |
   |   (fretwork_       |   (harmony_                 |   (harmony_finance_     |
   |    guitars)        |    marketing)               |    reporting)           |
   |                    |                              |                         |
   |   Sources          |                              |                         |
   |   Staging (6)      |                              |                         |
   |   Intermediate (3) |                              |                         |
   |   Marts:           |                              |                         |
   |     dim_customers -|-> loyalty_campaign_targets   |                         |
   |     fct_sales_     -|-> regional_performance      |-> consolidated_revenue  |
   |       orders       |                              |                         |
   |     dim_b2b_       |                              |-> b2b_account_health_   |
   |       customers    |                              |     report              |
   |     fct_b2b_orders |                              |-> consolidated_revenue  |
   |                    |                              |                         |
   |   Semantic Layer   |                              |                         |
   |   (9 metrics)      |                              |                         |
   ==================================================================================
         |
    Cortex Analyst / Streamlit Chat App
```

---

## Project Structure

This repo contains **3 independent dbt projects** connected via dbt Mesh:

```
orange_roadshow_dbt/
|
|-- platform/                  # PRODUCER: Core data platform
|   |-- dbt_project.yml        #   Project: fretwork_guitars
|   |-- packages.yml           #   dbt_utils, dbt_expectations, semantic_view
|   |-- profiles.yml.example
|   |-- models/
|   |   |-- staging/retail/    #   6 staging models (views)
|   |   |-- intermediate/      #   3 intermediate models (ephemeral)
|   |   |-- marts/core/        #   dim_customers, fct_sales_orders (public)
|   |   |-- marts/finance/     #   fct_b2b_orders (public)
|   |   |-- semantic/          #   MetricFlow semantic models + metrics
|   |   +-- semantic_views/    #   Snowflake Cortex Analyst views
|   +-- tests/                 #   3 custom data tests
|
|-- marketing/                 # CONSUMER: Marketing analytics team
|   |-- dbt_project.yml        #   Project: harmony_marketing
|   |-- dependencies.yml       #   Depends on: fretwork_guitars
|   |-- profiles.yml.example
|   +-- models/
|       |-- loyalty_campaign_targets.sql   # Campaign segmentation
|       +-- regional_performance.sql       # Geo/monthly performance
|
|-- finance/                   # CONSUMER: Finance reporting team
|   |-- dbt_project.yml        #   Project: harmony_finance_reporting
|   |-- dependencies.yml       #   Depends on: fretwork_guitars
|   |-- profiles.yml.example
|   +-- models/
|       |-- consolidated_revenue.sql       # Unified B2C + B2B revenue
|       +-- b2b_account_health_report.sql  # Account risk assessment
|
|-- docs/                      # Demo scripts and setup guides
|-- snowflake/                 # Snowflake SQL setup scripts
+-- streamlit/                 # Cortex Analyst chat app
```

### How the Mesh Works

| Concept | Implementation |
|---------|---------------|
| **Producer** | `platform/` publishes 4 mart models with `access: public` and enforced data contracts |
| **Consumers** | `marketing/` and `finance/` reference upstream models via `ref('fretwork_guitars', 'model_name')` |
| **Dependencies** | Each consumer declares `dependencies.yml` pointing to `fretwork_guitars` |
| **Contracts** | All public models enforce column types and constraints — breaking changes are caught at build time |
| **Groups** | Platform models are organized into `core` (Data Eng) and `finance` (Finance Analytics) groups |

### Public API (models shared via Mesh)

| Model | Group | Description |
|-------|-------|-------------|
| `dim_customers` | core | B2C customer dimension (SCD2 resolved, 1 row/customer) |
| `dim_b2b_customers` | core | B2B account dimension with health scoring |
| `fct_sales_orders` | core | B2C orders with revenue derived from parsed JSON |
| `fct_b2b_orders` | finance | B2B orders with status classification |

---

## Demo Structure

| Act | Duration | Message |
|-----|----------|---------|
| **Act 1** — Raw Data + AI = Chaos | 5 min | Cortex Analyst on raw Fivetran tables gives wrong answers |
| **Act 2** — dbt Brings Order | 10 min | dbt transformations, contracts, tests, Semantic Layer |
| **Act 3** — AI + dbt = Trust | 5 min | Same questions, correct answers — same AI, better foundation |
| **Act 4** — dbt Mesh | 5 min | Marketing & Finance teams consume governed data independently |

### What breaks in Act 1 (with your actual data)

| Problem | Raw table | Why it breaks |
|---------|-----------|--------------|
| No revenue column | `SALES_ORDERS` | `ORDERED_PRODUCTS` is a JSON text blob — Cortex can't compute revenue |
| SCD2 inflation | `CUSTOMERS` (28.8K rows) | Multiple rows per `CUSTOMER_ID` — AI double-counts customers |
| Epoch dates | `SALES_ORDERS.ORDER_DATETIME` | Stored as a NUMBER — time filters produce nonsense |
| Unreadable segments | `CUSTOMERS.LOYALTY_SEGMENT` | Raw number `3` instead of `"Gold"` — lookup not joined |

---

## Quick Start

**Full setup:** See `docs/SETUP_GUIDE.md`

### 1. Platform project (producer)
```bash
cd platform
dbt deps && dbt build
```

### 2. Marketing project (consumer)
```bash
cd marketing
dbt deps && dbt build
```

### 3. Finance project (consumer)
```bash
cd finance
dbt deps && dbt build
```

### 4. Cortex Analyst + Streamlit
```bash
# In Snowflake, run:
snowflake/01_cortex_raw_semantic_view.sql
snowflake/02_cortex_dbt_semantic_view.sql
# Deploy Streamlit app:
streamlit/setup_sis_app.sql
```

---

## Key Metrics (dbt Semantic Layer)

| Metric | Type | Definition |
|--------|------|------------|
| `total_b2c_revenue` | simple | Sum of `total_revenue` from `fct_sales_orders` (derived from parsed JSON) |
| `total_b2c_orders` | simple | Count of B2C orders |
| `avg_b2c_order_value` | ratio | `b2c_revenue / order_count` |
| `total_b2b_revenue` | simple | Sum of `amount` from `fct_b2b_orders` |
| `b2b_cancellation_rate` | ratio | `cancelled_amount / b2b_revenue` |
| `avg_b2b_order_value` | ratio | `b2b_revenue / b2b_order_count` |
| `total_customers` | simple | Count of active B2C customers (SCD2 resolved) |
| `total_units_purchased` | simple | Total units across all customers |
| `avg_units_per_customer` | ratio | `total_units / customer_count` |

---

## Source Data

| Table | Rows | Description |
|-------|------|-------------|
| `CUSTOMERS` | 28,813 | SCD2 B2C customers with LAT/LON, loyalty segment FK |
| `LOYALTY_SEGMENTS` | 4 | Lookup: segment ID -> description (Bronze/Silver/Gold/Platinum) |
| `SALES_ORDERS` | 4,074 | B2C orders — no amount column, ORDERED_PRODUCTS is raw JSON |
| `RET_CUSTOMERS` | 100 | B2B accounts |
| `RET_ORDERS` | 2,000 | B2B orders with clean AMOUNT field |
| `RET_TICKETS` | 150 | B2B support tickets |

---

## Partner Positioning

**Fivetran:** Moves retail data from Google Cloud SQL to Snowflake reliably. Every row, every table, perfectly synced.

**dbt:** Transforms raw Fivetran data into governed, tested, semantically rich analytics. Resolves SCD2, parses JSON, joins lookups, defines metrics once. dbt Mesh enables independent teams to build on top of trusted data.

**Snowflake:** Central data platform + Cortex Analyst for natural language queries. Quality of AI answers depends entirely on quality of underlying data.

**Key message:** "Fivetran moved the data. Snowflake stores it. But without dbt in the middle, AI gets the wrong answer — every time. dbt is the trust layer. dbt Mesh scales that trust across teams."

---

## Snowflake Connection Details

| Setting | Value |
|---------|-------|
| Database | `HICHAMB_FIVETRAN_DEMO` |
| Raw schema | `RETAIL_DEMO_RETAIL` |
| Platform output | `MARTS` schema |
| Marketing output | `MARKETING` schema |
| Finance output | `FINANCE` schema |
| Warehouse | `DBT_DEV_WH` |
| Role | `TRANSFORMER` |
