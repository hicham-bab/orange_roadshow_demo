# Demo Script — dbt + Snowflake + Fivetran

**Total time:** ~20 minutes
**Core message:** dbt is the trust layer between your data and AI. Without it, AI answers are confidently wrong.

**Data:** Retail dataset (Google Cloud SQL → Fivetran → Snowflake)
- `HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL` — raw Fivetran tables
- `HICHAMB_FIVETRAN_DEMO.MARTS` — dbt-governed mart tables

---

## Setup (Before the Demo)

Have these tabs open:
1. **Streamlit app** — in "Raw Data" mode, pre-typed question ready
2. **dbt Cloud** — Explorer DAG view
3. **Snowflake Worksheets** — for ad-hoc raw queries if needed

Pre-type (don't send yet): "What was our total revenue last month?"

---

## ACT 1 — "Raw Data + AI = Chaos" (5 min)

**Open Streamlit in "Raw Data" mode.**

*Say:*
> "Our retail data is synced from our PostgreSQL database into Snowflake via Fivetran. This is a Google Cloud SQL source — Fivetran moves it perfectly. Let's see what happens when we point Cortex Analyst straight at those raw tables."

---

**Type:** "What was our total revenue last month?"

*What Cortex will struggle with:*
- `SALES_ORDERS` has **no revenue column** — `ORDERED_PRODUCTS` is raw text/JSON
- Cortex may return null, use `NUMBER_OF_LINE_ITEMS` as a proxy, or fail to generate SQL
- If it tries `B2B.AMOUNT`, it's mixing B2B orders with B2C — wrong

*Say:*
> "There's no revenue column in the raw SALES_ORDERS table. ORDERED_PRODUCTS is raw text — it contains product details buried in a JSON blob that Cortex can't parse. The AI either returns nothing or makes up a proxy. Neither is right."

---

**Type:** "How many customers do we have by loyalty tier?"

*What goes wrong:*
- `LOYALTY_SEGMENT` on CUSTOMERS is a raw number: `1`, `2`, `3`, `4`
- The `LOYALTY_SEGMENTS` lookup table exists but is NOT described in the raw semantic view
- Cortex returns "segment 1: 5,200 customers" — no one knows what segment 1 means
- WORSE: CUSTOMERS is SCD2 — multiple rows per `CUSTOMER_ID` inflate all counts

*Say:*
> "Two problems. First, LOYALTY_SEGMENT is stored as a raw number — there's no label. The business doesn't talk about 'segment 3', they talk about 'Gold'. Second, the CUSTOMERS table has multiple rows per customer because it's an SCD2 history table. The count is inflated — we're double or triple counting customers who've changed address."

---

**Type:** "Which region has the most orders?"

*What goes wrong:*
- `ORDER_DATETIME` is a NUMBER (Unix epoch). Cortex treats it as a plain number, not a date
- Filtering "last month" produces nonsense because the field isn't date-typed

*Say:*
> "ORDER_DATETIME is stored as a Unix epoch number. The AI doesn't know it's a date — so any time-based filter on this field produces wrong results. It's comparing order 1,700,000,000 to order 1,700,000,100, not April to May."

---

*Pause.*

> "The data pipeline is perfect. Fivetran moved every row without losing a single record. But moved data is not analytics-ready data. There's no business logic, no type handling, no SCD2 resolution, no joins between lookup tables. The AI is doing its best — and failing because the foundation isn't there."

---

## ACT 2 — "dbt Brings Order" (10 min)

**Switch to dbt Cloud Explorer.**

*Walk the DAG:*

> "This is our dbt project. Same Snowflake data — transformed in layers."

---

**Point to staging layer:**
> "First, staging. Six models — one per source table. Key work here:
> - `stg_sales_orders`: converts ORDER_DATETIME from epoch to a proper DATE, and runs TRY_PARSE_JSON on ORDERED_PRODUCTS
> - `stg_customers`: converts VALID_FROM and VALID_TO epochs to dates, flags which rows are current
> - `stg_loyalty_segments`: clean lookup ready to join"

---

**Point to int_current_customers:**
> "This is the most important intermediate model. The CUSTOMERS source is SCD2 — multiple historical rows per customer. This model resolves it to one row per customer_id using the VALID_TO = 0 / NULL flag for current records, then joins the loyalty segment description. 'Segment 3' becomes 'Gold'."

---

**Point to int_sales_order_lines:**
> "This model explodes the ORDERED_PRODUCTS JSON array — one row per line item — and extracts product name, quantity, and unit price. This is where revenue is born. It doesn't exist in the source; dbt creates it."

---

**Open _core_models.yml. Show contracts and tests:**
> "Model contracts enforce the schema — if someone removes `total_revenue` or changes its type, the build fails. Tests validate: customer_ids are unique (SCD2 resolved), revenue is non-negative, every order has a valid customer."

---

**Navigate to Semantic Layer:**
> "Finally, metrics defined once in code: total_b2c_revenue, avg_b2c_order_value, b2b_cancellation_rate, total customers by loyalty tier. Version controlled. Tested. Serving any downstream tool consistently."

---

## ACT 3 — "AI + dbt = Trust" (5 min)

**Switch Streamlit to "dbt Marts" mode.**

> "Same questions. Same AI. Different data."

---

**Type:** "What was our total revenue last month?"
- Returns a dollar amount using `total_revenue` from `fct_sales_orders`
- Filtered correctly because `order_date` is a DATE

> "Revenue is now a first-class column — derived from the parsed line items, with a clear definition: sum of quantity × unit_price per order. One number. One definition."

---

**Type:** "How many customers do we have by loyalty tier?"
- Returns: "Gold: 4,200, Platinum: 1,100, Silver: 8,300, Bronze: 15,200"
- Correct count because SCD2 deduplicated by dbt

> "Now we see Gold, Silver, Platinum — not 3, 2, 1. And the count is correct because the SCD2 table has been resolved to one row per customer. dbt handled the deduplication, the join, the transformation."

---

**Type:** "Which region has the most B2C orders in the last 6 months?"
- Correct because `order_date` is a proper DATE field

> "Time filter works because the epoch was converted to a date in staging. This is why transformation isn't optional."

---

*Close:*
> "Same Cortex Analyst. Same data in Snowflake. Dramatically different answers. The difference is the layer between raw ingestion and AI consumption — that's dbt.

> And the Semantic Layer means Tableau, Hex, Google Sheets, and Cortex all get the same answer for 'revenue'. One definition, everywhere, version-controlled, tested. That's what 'dbt is essential in an AI world' means."

---

## Key Talking Points

| Act | Point | Soundbite |
|-----|-------|-----------|
| 1 | No revenue column | "ORDERED_PRODUCTS is a JSON blob. The AI can't compute revenue from raw text." |
| 1 | SCD2 inflation | "That's not 28K customers — it's 28K customer versions. Raw AI double-counts." |
| 1 | Epoch dates | "ORDER_DATETIME is a number, not a date. Time filters are meaningless on raw." |
| 1 | Unjoined lookup | "Loyalty segment 3 means nothing without joining the lookup. dbt does that join." |
| 2 | Parsing | "dbt creates revenue from the JSON. It doesn't exist in the source system." |
| 2 | SCD2 resolution | "int_current_customers: one row per customer, period." |
| 2 | Tests | "If the SCD2 resolution breaks, `assert_no_duplicate_current_customers` fails." |
| 3 | Consistency | "Gold not 3. A date not an epoch. Revenue not null." |

---

## Anticipated Questions

**"Can Cortex Analyst parse the JSON itself?"**
> "It can try — but it doesn't know your business rules. Which fields are revenue? What about cancelled orders? What if the JSON format changes? dbt encodes those decisions in version-controlled, tested SQL. Cortex just consumes the result."

**"Why not fix the source schema in PostgreSQL?"**
> "ORDERED_PRODUCTS as JSON is a legitimate source design — flexible for varied product catalogs. SCD2 is intentional for regulatory/audit reasons. The source system is built for transactions, not analytics. That's exactly why the transformation layer exists."

**"What does dbt add that a stored procedure couldn't?"**
> "Testing, documentation, lineage, version control, and the Semantic Layer. A stored procedure can transform data — it can't tell you which downstream AI tool is consuming which metric, or alert you when a schema change breaks an assumption."
