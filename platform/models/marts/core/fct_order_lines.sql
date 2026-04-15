/*
  fct_order_lines
  ================
  B2C order line-item fact table. Grain: one row per order + product.

  Enriched with product catalog data (category, cost) to enable
  margin analysis and product-level reporting. This is the governed
  line-item model — Cortex Analyst can answer product mix questions
  directly from this table.
*/

with lines as (
    select * from {{ ref('int_sales_order_lines') }}
),

products as (
    select * from {{ ref('stg_product_catalog') }}
)

select
    l.order_id,
    l.order_date,
    l.customer_id,
    l.line_number,
    l.product_id,
    coalesce(p.product_name, l.product_name)    as product_name,
    p.category                                  as product_category,
    p.subcategory                               as product_subcategory,
    l.quantity,
    l.unit_price,
    l.line_revenue,
    p.unit_cost::number(38, 2)                  as unit_cost,
    -- Margin only when cost data is available
    case
        when p.unit_cost is not null
        then l.line_revenue - (l.quantity * p.unit_cost)
    end::number(38, 2)                          as line_margin,
    p.product_id is not null                    as has_catalog_match

from lines l
left join products p on p.product_id = l.product_id
