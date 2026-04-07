with orders as (

    select
        order_key,
        customer_id,
        region,
        order_type,
        order_amount
    from {{ ref('retail_demo', 'fct_orders') }}

),

customers as (

    select distinct
        customer_id,
        region
    from {{ ref('retail_demo', 'dim_customers') }}

),

regional as (

    select
        o.region,
        count(case when o.order_type = 'b2c' then o.order_key end)             as total_b2c_orders,
        count(case when o.order_type = 'b2b' then o.order_key end)             as total_b2b_orders,
        cast(
            sum(case when o.order_type = 'b2b' then o.order_amount else 0 end)
            as number
        )                                                                        as total_b2b_revenue,
        cast(
            avg(case when o.order_type = 'b2b' then o.order_amount end)
            as number
        )                                                                        as avg_b2b_order_value,
        count(distinct o.customer_id)                                           as customer_count
    from orders o
    group by o.region

)

select
    region,
    total_b2c_orders,
    total_b2b_orders,
    total_b2b_revenue,
    avg_b2b_order_value,
    customer_count
from regional
order by total_b2b_revenue desc
