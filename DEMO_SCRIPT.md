# Demo Script: AI-Ready Data with Fivetran + dbt + Snowflake
## "Before AI Can Answer, You Need to Be Able to Trust It"

**Audience:** Snowflake prospects who just saw a Cortex / AI Features demo
**Duration:** ~20 minutes
**Core message:** AI is only as good as what's underneath. Snowflake can query your data — but can you audit, trust, and explain the answer?

---

## The Setup: One Provocative Question

> "The Snowflake team just showed you AI answering business questions. Before you invest in that, let me ask you one question:
> **If Cortex tells you revenue is up 12% this month — how do you know that's true?**
> Where did that number come from? When was the data last updated? Was it tested?
> If you can't answer those three questions, the AI answer is worthless — or worse, dangerous."

This demo shows how Fivetran + dbt makes your data **AI-ready**: fresh, tested, defined, and fully auditable from the question all the way back to the source row.

---

## ACT 1: The Source — "Where does the data come from?"

### What to show: Fivetran dashboard (your screenshots)

**Talking points:**
- "Data starts in a PostgreSQL database running in Google Cloud — your operational system."
- "Fivetran moves it to Snowflake every 6 hours, automatically."
- Point to the sync log: `Apr 6 4:41 PM — 1m 15s — Successful sync`
- "Every sync is logged. You can see exactly when data arrived: date, time, duration, rows loaded."
- Point to Schema tab: "6 tables, all selected, soft delete mode — meaning we never lose history."

**The audit trail Fivetran adds:**
Fivetran appends two columns to every single row it syncs:

| Column | What it means |
|--------|--------------|
| `_fivetran_synced` | Exact timestamp this row was last synced from the source |
| `_fivetran_deleted` | True if the source row was deleted (soft delete — we keep the history) |

> "This is your chain of custody at the ingestion layer. You can always answer: *when did this row arrive in Snowflake?*"

**Show in Snowflake:**
```sql
SELECT
    customer_id,
    customer_name,
    loyalty_segment,
    _fivetran_synced,
    _fivetran_deleted
FROM HICHAMB_FIVETRAN_DEMO.retail.customers
ORDER BY _fivetran_synced DESC
LIMIT 10;
```

Point out: every row has a sync timestamp. No row arrives without one.

---

## ACT 2: Freshness — "Is the data current right now?"

### What to show: dbt source freshness

```bash
cd ~/retail-fivetran-demo
dbt source freshness
```

**Expected output:**
```
Found 6 sources, configured with freshness
  customers .............. PASS  [0h 25m ago]
  loyalty_segments ....... PASS  [0h 25m ago]
  ret_customers .......... PASS  [0h 25m ago]
  ret_orders ............. PASS  [0h 25m ago]
  ret_tickets ............ PASS  [0h 25m ago]
  sales_orders ........... PASS  [0h 25m ago]
```

**Talking points:**
- "dbt runs this check automatically before any transformation. If data is stale, we know before building models."
- Open `models/staging/fivetran_retail/_sources.yml`, scroll to the freshness block:

```yaml
freshness:
  warn_after: {count: 7, period: hour}
  error_after: {count: 13, period: hour}
```

- "Fivetran syncs every 6 hours. We warn at 7 hours, error at 13. If Fivetran has an incident, dbt catches it before AI ever sees stale data."
- "Without this, Cortex could be answering questions about yesterday's data and you'd never know."

> **Audit question answered:** *When was this data last refreshed?*
> **Answer:** `_fivetran_synced` at row level + dbt freshness at source level.

---

## ACT 3: Data Quality — "Can we trust what's in the data?"

### What to show: dbt tests

```bash
dbt test --select staging
```

**Talking points:**
- "Before anything reaches the marts that AI queries, we run 40+ assertions."
- Open `_sources.yml` and walk through examples while tests run:

**Not null / Unique (correctness):**
```yaml
- name: id
  tests:
    - unique
    - not_null
- name: order_user_id
  tests:
    - not_null   # every order must have a customer
```

**Accepted values (domain integrity):**
```yaml
- name: status
  tests:
    - accepted_values:
        values: ['completed', 'cancelled', 'pending', 'processing', 'refunded']
```

- "If a new status appears in the source — say the dev team adds `'on_hold'` — this test fails. We know before AI does."
- "Without tests, AI might calculate a cancellation rate that's missing 15% of cancellations because the status label changed."

**Show the staging layer filter in any staging SQL:**
```sql
WHERE _fivetran_deleted IS DISTINCT FROM TRUE
```
- "We never serve deleted rows to the transformation layer. Fivetran tracks the deletes; dbt honors them."

> **Audit question answered:** *Is this data correct and complete?*
> **Answer:** 40+ assertions, run on every pipeline execution, before data reaches any mart.

---

## ACT 4: Lineage — "How was this number calculated?"

### What to show: dbt docs lineage graph

```bash
dbt docs generate
dbt docs serve
```

Open browser, navigate to the lineage graph for `fct_orders`. Walk the graph:

```
[source: retail.sales_orders]     [source: retail.ret_orders]
         |                                    |
[stg_sales_orders]              [stg_ret_orders]
         |                                    |
         |                    [int_ret_orders_with_customers]
         |                                    |
         +---------------+--------------------+
                         |
                    [fct_orders]
                         |
              [semantic model: orders]
                         |
                  [metric: total_revenue]
```

**Talking points:**
- "Every metric has a complete lineage. Click `total_revenue` → it points to `fct_orders.order_amount` → which comes from either `stg_ret_orders.amount` (B2B) or is null (B2C orders counted, not valued)."
- "Click on `stg_ret_orders` → it comes from `source: fivetran_retail.ret_orders` → synced from PostgreSQL via Fivetran."
- "An analyst, a regulator, or your CFO can trace any number back to the raw row in the source database."

> **Audit question answered:** *How was this number computed?*
> **Answer:** Full DAG lineage, column-level descriptions, model-by-model documentation.

---

## ACT 5: Semantic Layer — "What does this metric actually mean?"

### What to show: semantic_models.yml and metrics.yml

Open `models/marts/semantic_models.yml`. Walk through the `orders` semantic model:

```yaml
- name: orders
  model: ref('fct_orders')
  entities:
    - name: order
      type: primary
      expr: order_key
    - name: customer
      type: foreign
      expr: customer_id
  dimensions:
    - name: order_date
      type: time
      time_granularity: day
    - name: order_type      # 'b2b' or 'b2c'
    - name: order_status
    - name: region
  measures:
    - name: total_revenue
      expr: order_amount
      agg: sum
    - name: order_count
      expr: order_key
      agg: count_distinct
    - name: cancelled_order_count
      expr: "case when order_status = 'cancelled' then 1 else 0 end"
      agg: sum
```

**Talking points:**
- "This is where the business definition lives. `total_revenue` is *explicitly* `sum(order_amount)`. Not inferred. Not hallucinated."
- "When Snowflake Cortex queries your warehouse directly, it sees column names and guesses what they mean. Here, we define it."
- Open `metrics.yml`:

```yaml
- name: cancellation_rate
  type: ratio
  type_params:
    numerator: cancelled_order_count
    denominator: order_count

- name: revenue_per_customer
  type: derived
  type_params:
    expr: "{{ metric('total_revenue') }} / {{ metric('customer_count') }}"
```

- "Every metric is a first-class object. You can slice `cancellation_rate` by region, by order_type, by month — and the denominator always matches the numerator. No accidental filter mismatches."
- "And because it's in code, it's version-controlled. You can see who changed the definition of `total_revenue`, when, and why."

> **Audit question answered:** *What does this metric mean?*
> **Answer:** Explicit, version-controlled definitions. Business logic lives in code, not in someone's head or a BI tool config.

---

## ACT 6: The Full Audit Chain — "Trace an AI answer back to its source"

This is the closing moment. Draw the chain end-to-end:

```
AI Question:
"What is total revenue by region this month?"
          |
          v
Metric: total_revenue
  → defined as sum(order_amount) in semantic_models.yml
          |
          v
Model: fct_orders
  → union of B2B and B2C orders
  → tested: not_null, unique, accepted_values on status
          |
          v
Staging: stg_ret_orders
  → cast(amount as numeric(18,2))
  → filters _fivetran_deleted rows
  → tested at source level
          |
          v
Source: HICHAMB_FIVETRAN_DEMO.retail.ret_orders
  → freshness monitored: warn 7h, error 13h
  → _fivetran_synced: 2026-04-06 16:41 PM
          |
          v
Fivetran Sync
  → Source: Google Cloud PostgreSQL
  → Last sync: Apr 6 4:41 PM, 1m 15s, Successful
  → Sync log: auditable history in Fivetran dashboard
```

**Closing line:**

> "When someone asks *'can we trust this AI answer?'* — with this stack, the answer is yes. You can trace every number from the AI response back to the exact row in your source database, the exact Fivetran sync that brought it, and every quality check it passed on the way.
>
> **That's not just AI. That's auditable AI. That's the difference.**"

---

## Demo Commands Cheat Sheet

```bash
# Setup
cd ~/retail-fivetran-demo
export SNOWFLAKE_ACCOUNT=cmvgrnf.zna84829
export SNOWFLAKE_USER=HB
export SNOWFLAKE_PASSWORD=<your_password>
export SNOWFLAKE_WAREHOUSE=COMPUTE_WH

# Install packages
~/.local/bin/dbt deps

# ACT 2: Freshness check
~/.local/bin/dbt source freshness

# ACT 3: Quality tests (staging only, fast)
~/.local/bin/dbt test --select staging

# Run full pipeline
~/.local/bin/dbt build

# ACT 4: Lineage docs
~/.local/bin/dbt docs generate
~/.local/bin/dbt docs serve
# → open http://localhost:8080
```

---

## Objection Handling

| Snowflake says | Your response |
|----------------|---------------|
| "Cortex can query your data directly" | "Query what, exactly? Raw tables with no tests, no freshness guarantee, and column names like `ret_orders.amount`? We define what *revenue* means before AI touches it." |
| "We have Snowflake data quality features" | "Great — and dbt orchestrates those checks into your pipeline, with lineage, version control, and the ability to block the build if tests fail. It's not either/or." |
| "Our semantic layer handles definitions" | "Show me the version history of your metric definitions. With dbt, every change is a git commit — who changed it, when, and why." |
| "This is too complex" | "Your data is complex. The question is whether that complexity is hidden or visible. We make it visible." |

---

## Files to Have Open During Demo

1. **Fivetran browser tab** — connection status + schema view (your screenshots)
2. **Snowflake browser tab** — `HICHAMB_FIVETRAN_DEMO.retail` tables
3. **Terminal** — for dbt commands
4. **VS Code / editor** with these files open:
   - `models/staging/fivetran_retail/_sources.yml` — freshness + source tests
   - `models/staging/fivetran_retail/stg_ret_orders.sql` — show the `_fivetran_deleted` filter + `cast()`
   - `models/marts/semantic_models.yml` — the metric definitions
   - `models/marts/metrics.yml` — show `cancellation_rate` ratio + `revenue_per_customer` derived
5. **dbt docs** browser tab (after `dbt docs serve`) — lineage graph
