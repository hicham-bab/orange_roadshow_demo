/*
  regional_performance
  ====================
  Cross-project consumption: marketing team's view of regional sales performance.
  Used for geo-targeted campaigns and regional budget allocation.
*/

with orders as (
    select * from {{ ref('harmony_central_data', 'fct_sales_orders') }}
),

customers as (
    select * from {{ ref('harmony_central_data', 'dim_customers') }}
)

select
    c.region,
    c.state,
    date_trunc('month', o.order_date)   as order_month,
    count(distinct o.order_id)          as total_orders,
    count(distinct o.customer_id)       as active_customers,
    sum(o.total_revenue)                as monthly_revenue,
    avg(o.total_revenue)                as avg_order_value,
    sum(case when o.has_promo then 1 else 0 end) as promo_orders,
    round(sum(case when o.has_promo then 1 else 0 end)::numeric
          / nullif(count(*), 0) * 100, 1)  as promo_adoption_pct

from orders o
inner join customers c on c.customer_id = o.customer_id
group by c.region, c.state, date_trunc('month', o.order_date)
