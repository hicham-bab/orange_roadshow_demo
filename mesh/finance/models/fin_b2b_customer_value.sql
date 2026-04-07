with b2b_orders as (

    select
        customer_id,
        customer_name,
        region,
        order_key,
        order_amount,
        order_status
    from {{ ref('retail_demo', 'fct_orders') }}
    where order_type = 'b2b'

),

order_summary as (

    select
        customer_id,
        max(customer_name)                                                       as customer_name,
        max(region)                                                              as region,
        count(order_key)                                                         as total_orders,
        cast(sum(order_amount) as number)                                       as total_revenue,
        cast(avg(order_amount) as number)                                       as avg_order_value,
        count(case when order_status = 'cancelled' then order_key end)          as cancelled_orders,
        cast(
            count(case when order_status = 'cancelled' then order_key end) * 1.0
            / nullif(count(order_key), 0)
            as number
        )                                                                        as cancellation_rate
    from b2b_orders
    group by customer_id

),

tickets as (

    select
        customer_id,
        count(ticket_key)                                                        as support_tickets,
        count(case when is_open = true then ticket_key end)                     as open_tickets
    from {{ ref('retail_demo', 'fct_support_tickets') }}
    group by customer_id

),

joined as (

    select
        o.customer_id,
        o.customer_name,
        o.region,
        o.total_orders,
        o.total_revenue,
        o.avg_order_value,
        o.cancelled_orders,
        o.cancellation_rate,
        coalesce(t.support_tickets, 0)                                          as support_tickets,
        coalesce(t.open_tickets, 0)                                             as open_tickets
    from order_summary o
    left join tickets t
        on o.customer_id = t.customer_id

)

select
    customer_id,
    customer_name,
    region,
    total_orders,
    total_revenue,
    avg_order_value,
    cancelled_orders,
    cancellation_rate,
    support_tickets,
    open_tickets,
    case
        when cancellation_rate > 0.3 or open_tickets > 2 then 'at_risk'
        when cancellation_rate > 0.1 or open_tickets > 0 then 'needs_attention'
        else 'healthy'
    end                                                                          as customer_health_score
from joined
order by total_revenue desc
