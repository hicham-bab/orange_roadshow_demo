{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('dim_customers') }}
),

orders as (
    select * from {{ ref('fct_sales_orders') }}
),

customer_order_metrics as (
    select
        customer_id,
        min(order_date) as first_order_date,
        cast(sum(total_revenue) as number) as total_revenue,
        cast(count(order_id) as number) as order_count,
        cast(avg(total_revenue) as number(38,2)) as average_order_value
    from orders
    group by customer_id
)

select
    c.customer_id,
    c.customer_name,
    m.first_order_date,
    coalesce(m.total_revenue, 0)::number as total_revenue,
    coalesce(m.order_count, 0)::number as order_count,
    coalesce(m.average_order_value, 0)::number(38,2) as average_order_value,
    coalesce(datediff('day', m.first_order_date, current_date()), 0)::number as days_since_first_order
from customers c
left join customer_order_metrics m
    on c.customer_id = m.customer_id
