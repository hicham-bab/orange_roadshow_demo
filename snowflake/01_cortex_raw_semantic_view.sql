-- =============================================================================
-- Cortex Analyst Semantic View — RAW DATA (Act 1: "Chaos")
-- =============================================================================
-- Points at raw Fivetran tables in HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.
-- Intentionally minimal to demonstrate what AI gets wrong on ungoverned data:
--
--   1. ORDER_DATETIME is a NUMBER (epoch) — Cortex doesn't know it's a date
--   2. ORDERED_PRODUCTS is opaque TEXT — Cortex cannot compute revenue
--   3. LOYALTY_SEGMENT is a raw number (1/2/3/4) — no human-readable label
--   4. CUSTOMERS is SCD2 — duplicate customer_ids inflate all customer counts
--   5. No join between LOYALTY_SEGMENTS and CUSTOMERS described
--
-- Run as SYSADMIN or TRANSFORMER role.
-- =============================================================================

USE DATABASE HICHAMB_FIVETRAN_DEMO;
USE SCHEMA RETAIL_DEMO_RETAIL;

CREATE OR REPLACE SEMANTIC VIEW HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.cortex_retail_raw_sv

  TABLES (
    sales_orders  AS HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.SALES_ORDERS
      PRIMARY KEY (ID),
    customers     AS HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.CUSTOMERS
      PRIMARY KEY (ID),
    ret_orders    AS HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.RET_ORDERS
      PRIMARY KEY (ID),
    ret_customers AS HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.RET_CUSTOMERS
      PRIMARY KEY (ID)
  )

  RELATIONSHIPS (
    sales_orders (CUSTOMER_ID) REFERENCES customers (CUSTOMER_ID),
    ret_orders (ORDER_USER_ID) REFERENCES ret_customers (ID)
  )

  FACTS (
    -- No revenue column on SALES_ORDERS — ORDERED_PRODUCTS is raw text
    sales_orders.NUMBER_OF_LINE_ITEMS AS number_of_line_items
      COMMENT 'Number of line items. No revenue column exists in the raw table.',
    ret_orders.AMOUNT AS b2b_order_amount
      COMMENT 'B2B order amount',
    customers.UNITS_PURCHASED AS units_purchased
      COMMENT 'Units purchased (may be duplicated due to SCD2 — multiple rows per customer)'
  )

  DIMENSIONS (
    -- ORDER_DATETIME is epoch NUMBER — Cortex will treat it as a plain number, not a date
    sales_orders.ORDER_DATETIME AS order_datetime
      COMMENT 'Order date as Unix epoch number. NOT a date type. Analysis may produce wrong results.',
    sales_orders.ORDERED_PRODUCTS AS ordered_products
      COMMENT 'Raw text blob of ordered products. Revenue cannot be computed from this field.',
    sales_orders.PROMO_INFO AS promo_info
      COMMENT 'Promotion information (raw text)',
    customers.CUSTOMER_NAME AS customer_name,
    customers.CITY AS city,
    customers.REGION AS region,
    -- LOYALTY_SEGMENT is just a number — no segment label available here
    customers.LOYALTY_SEGMENT AS loyalty_segment_number
      COMMENT 'Loyalty segment as raw number (1/2/3/4). No label without joining loyalty_segments table.',
    ret_orders.STATUS AS b2b_order_status,
    ret_customers.NAME AS b2b_customer_name,
    ret_customers.REGION AS b2b_region
  );

GRANT SELECT ON SEMANTIC VIEW HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.cortex_retail_raw_sv
    TO ROLE TRANSFORMER;
