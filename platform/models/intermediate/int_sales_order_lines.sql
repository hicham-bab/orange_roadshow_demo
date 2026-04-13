/*
  int_sales_order_lines
  =====================
  Explodes ORDERED_PRODUCTS JSON array into one row per order line item.

  Expected JSON format:
    [{"product_id": 101, "name": "Widget A", "qty": 2, "price": 29.99}, ...]

  Falls back gracefully if JSON is malformed — those rows are excluded.

  Demo talking point (Act 1 chaos):
    Raw SALES_ORDERS has no revenue column — ORDERED_PRODUCTS is opaque TEXT.
    Cortex Analyst cannot compute revenue without this transformation.
    After dbt, revenue is a first-class column on fct_sales_orders.
*/

with orders as (
    select
        order_id,
        order_date,
        customer_id,
        ordered_products_json
    from {{ ref('stg_sales_orders') }}
    where ordered_products_json is not null   -- exclude unparseable rows
),

exploded as (
    select
        o.order_id,
        o.order_date,
        o.customer_id,
        f.index                                         as line_number,
        f.value:product_id::number                      as product_id,
        f.value:name::varchar                           as product_name,
        -- Support both "qty" and "quantity" key variants
        coalesce(
            f.value:qty::number,
            f.value:quantity::number,
            1
        )                                               as quantity,
        coalesce(
            f.value:price::number,
            f.value:unit_price::number,
            0
        )                                               as unit_price
    from orders o,
    lateral flatten(input => o.ordered_products_json) f
)

select
    order_id,
    order_date,
    customer_id,
    line_number,
    product_id,
    product_name,
    quantity,
    unit_price,
    quantity * unit_price                               as line_revenue
from exploded
