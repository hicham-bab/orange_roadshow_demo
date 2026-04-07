with b2b_orders as (

    select
        order_key,
        order_date,
        order_amount,
        order_status
    from {{ ref('retail_demo', 'fct_orders') }}
    where order_type = 'b2b'

),

monthly as (

    select
        cast(date_trunc('month', order_date) as date)                           as order_month,
        count(order_key)                                                         as order_count,
        cast(sum(order_amount) as number)                                       as total_revenue,
        count(case when order_status = 'cancelled' then order_key end)          as cancelled_orders,
        cast(
            count(case when order_status = 'cancelled' then order_key end) * 1.0
            / nullif(count(order_key), 0)
            as number
        )                                                                        as cancellation_rate,
        cast(avg(order_amount) as number)                                       as avg_order_value
    from b2b_orders
    group by cast(date_trunc('month', order_date) as date)

)

select
    order_month,
    order_count,
    total_revenue,
    cancelled_orders,
    cancellation_rate,
    avg_order_value
from monthly
order by order_month desc
