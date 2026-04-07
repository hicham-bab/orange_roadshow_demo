with orders as (

    select
        order_key,
        region,
        order_type,
        order_status,
        order_amount
    from {{ ref('retail_demo', 'fct_orders') }}

),

aggregated as (

    select
        region,
        order_type,
        order_status,
        count(order_key)                                                         as order_count,
        cast(sum(order_amount) as number)                                       as total_order_amount,
        cast(avg(order_amount) as number)                                       as avg_order_amount
    from orders
    group by
        region,
        order_type,
        order_status

)

select
    region,
    order_type,
    order_status,
    order_count,
    total_order_amount,
    avg_order_amount
from aggregated
order by
    region,
    order_type,
    order_status
