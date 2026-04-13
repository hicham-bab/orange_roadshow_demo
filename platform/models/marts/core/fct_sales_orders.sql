/*
  fct_sales_orders
  ================
  B2C sales order fact table. Grain: one row per order.

  Revenue is derived from int_sales_order_lines (parsed ORDERED_PRODUCTS JSON).
  For orders where JSON could not be parsed, revenue is null — these are flagged
  with has_unparsed_products = true for data quality monitoring.
*/

with orders as (
    select * from {{ ref('stg_sales_orders') }}
),

order_revenue as (
    select
        order_id,
        sum(line_revenue)   as total_revenue,
        count(*)            as parsed_line_items
    from {{ ref('int_sales_order_lines') }}
    group by order_id
)

select
    o.order_id,
    o.order_number,
    o.customer_id,
    o.order_date,
    o.order_timestamp,
    o.number_of_line_items,
    coalesce(r.total_revenue, 0)            as total_revenue,
    r.parsed_line_items,
    o.promo_code,
    o.promo_code is not null                as has_promo,
    -- Flag orders where JSON parsing failed
    (o.ordered_products_json is null
     and o.ordered_products_raw is not null) as has_unparsed_products
from orders o
left join order_revenue r on r.order_id = o.order_id
where o.order_date is not null
