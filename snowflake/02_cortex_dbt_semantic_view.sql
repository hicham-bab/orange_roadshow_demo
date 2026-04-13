-- =============================================================================
-- Cortex Analyst Semantic View — dbt MARTS (Act 3: "Trust")
-- =============================================================================
-- Points at dbt-governed mart tables. Every problem from Act 1 is solved:
--
--   1. order_date is a proper DATE — time analysis just works
--   2. total_revenue is a NUMBER derived by dbt from parsed ORDERED_PRODUCTS
--   3. loyalty_segment_description is "Gold" / "Platinum" — not "3" / "4"
--   4. dim_customers has one row per customer (SCD2 resolved by dbt)
--   5. B2B health score and risk flags add AI-ready business context
--
-- Run as SYSADMIN or TRANSFORMER role.
-- Assumes dbt has been run and marts are populated.
-- =============================================================================

USE DATABASE HICHAMB_FIVETRAN_DEMO;

-- Create a MARTS schema if your dbt target schema is different — adjust to match
-- your dbt profile's schema (e.g., DEV_HICHAM_MARTS or PROD_MARTS)
-- In this example we assume dbt writes to HICHAMB_FIVETRAN_DEMO.MARTS

CREATE OR REPLACE SEMANTIC VIEW HICHAMB_FIVETRAN_DEMO.MARTS.cortex_retail_dbt_sv

  COMMENT = 'Governed retail semantic view over dbt marts. Revenue, customers, loyalty, and B2B health.'

  TABLES (
    sales_orders  AS HICHAMB_FIVETRAN_DEMO.MARTS.FCT_SALES_ORDERS
      PRIMARY KEY (order_id)
      COMMENT 'B2C sales fact. One row per order. Revenue computed from parsed order lines by dbt.',

    customers     AS HICHAMB_FIVETRAN_DEMO.MARTS.DIM_CUSTOMERS
      PRIMARY KEY (customer_id)
      COMMENT 'B2C customer dimension. SCD2 resolved. One row per customer. Loyalty tier joined.',

    b2b_orders    AS HICHAMB_FIVETRAN_DEMO.MARTS.FCT_B2B_ORDERS
      PRIMARY KEY (order_id)
      COMMENT 'B2B orders with clean revenue amount.',

    b2b_customers AS HICHAMB_FIVETRAN_DEMO.MARTS.DIM_B2B_CUSTOMERS
      PRIMARY KEY (b2b_customer_id)
      COMMENT 'B2B accounts with health score, ticket counts, and return rate.'
  )

  RELATIONSHIPS (
    sales_orders (customer_id) REFERENCES customers (customer_id),
    b2b_orders (b2b_customer_id) REFERENCES b2b_customers (b2b_customer_id)
  )

  FACTS (
    sales_orders.total_revenue AS b2c_revenue
      SYNONYMS ('b2c sales', 'online revenue', 'sales', 'revenue')
      COMMENT 'Total B2C order revenue in USD. Derived by dbt from parsed ORDERED_PRODUCTS line items. Governed definition.',

    sales_orders.number_of_line_items AS line_items
      SYNONYMS ('items', 'products ordered')
      COMMENT 'Number of line items per order.',

    customers.units_purchased AS units_purchased
      SYNONYMS ('total units', 'volume')
      COMMENT 'Total units purchased by this customer.',

    b2b_orders.amount AS b2b_revenue
      SYNONYMS ('b2b sales', 'wholesale revenue', 'account revenue')
      COMMENT 'B2B order revenue in USD.',

    b2b_customers.total_revenue AS b2b_account_total_revenue
      COMMENT 'Total lifetime revenue for this B2B account.',

    b2b_customers.health_score AS account_health_score
      SYNONYMS ('health', 'account score')
      COMMENT '0–100 score. Lower = more open tickets / higher return rate.',

    b2b_customers.open_tickets AS open_support_tickets
      SYNONYMS ('open tickets', 'unresolved tickets')
      COMMENT 'Number of currently open support tickets for this B2B account.'
  )

  DIMENSIONS (
    sales_orders.order_date AS order_date
      SYNONYMS ('date', 'purchase date', 'transaction date')
      COMMENT 'Order date as DATE type. Converted from epoch by dbt.',

    sales_orders.has_promo AS has_promo
      SYNONYMS ('promoted', 'discounted', 'promo used')
      COMMENT 'True if a promotional code was applied to the order.',

    customers.customer_name AS customer_name
      SYNONYMS ('customer', 'name', 'buyer'),

    customers.region AS region
      SYNONYMS ('location', 'area'),

    customers.state AS state,
    customers.city  AS city,

    customers.loyalty_segment_description AS loyalty_tier
      SYNONYMS ('loyalty', 'segment', 'tier', 'loyalty segment')
      COMMENT 'Loyalty tier name (e.g., Bronze, Silver, Gold, Platinum). Joined from loyalty_segments lookup by dbt.',

    customers.customer_value_segment AS value_segment
      SYNONYMS ('value tier', 'customer segment')
      COMMENT 'Value segment: high_value (top 20% by units purchased), mid_value, low_value.',

    b2b_orders.order_date AS b2b_order_date
      COMMENT 'B2B order date.',

    b2b_orders.status AS b2b_order_status
      COMMENT 'B2B order status.',

    b2b_orders.is_cancelled_or_returned AS is_cancelled_or_returned
      SYNONYMS ('cancelled', 'returned')
      COMMENT 'True if this B2B order was cancelled or returned.',

    b2b_customers.b2b_customer_id AS b2b_customer_id,
    b2b_customers.company_name AS company_name
      SYNONYMS ('company', 'account', 'business'),

    b2b_customers.region AS b2b_region,

    b2b_customers.account_health_status AS account_health_status
      SYNONYMS ('health status', 'account risk', 'risk')
      COMMENT 'Account health: healthy, needs_attention, at_risk. Derived by dbt from ticket + return data.'
  );

GRANT SELECT ON SEMANTIC VIEW HICHAMB_FIVETRAN_DEMO.MARTS.cortex_retail_dbt_sv
    TO ROLE TRANSFORMER;
