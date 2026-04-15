-- Test: sum of line-item revenue should match order-level total_revenue
-- Fails if there is a mismatch greater than 0.01 (rounding tolerance)

with order_line_totals as (
    select
        order_id,
        sum(line_revenue) as line_total
    from {{ ref('fct_order_lines') }}
    group by order_id
),

orders as (
    select
        order_id,
        total_revenue
    from {{ ref('fct_sales_orders') }}
    where total_revenue > 0
)

select
    o.order_id,
    o.total_revenue,
    lt.line_total,
    abs(o.total_revenue - lt.line_total) as diff
from orders o
inner join order_line_totals lt on lt.order_id = o.order_id
where abs(o.total_revenue - lt.line_total) > 0.01
