/*
  int_b2b_customer_health
  =======================
  Aggregates B2B customer metrics from orders and support tickets.
  Produces a health score and risk flag for each B2B account.
*/

with b2b_customers as (
    select * from {{ ref('stg_ret_customers') }}
),

orders as (
    select
        b2b_customer_id,
        count(*)                                    as total_orders,
        sum(amount)                                 as total_revenue,
        sum(case when status in ('cancelled', 'returned') then amount else 0 end)
                                                    as cancelled_revenue,
        sum(case when status in ('cancelled', 'returned') then 1 else 0 end)
                                                    as cancelled_orders,
        max(order_date)                             as last_order_date
    from {{ ref('stg_ret_orders') }}
    group by b2b_customer_id
),

tickets as (
    select
        b2b_customer_id,
        count(*)                                    as total_tickets,
        sum(case when status = 'open' then 1 else 0 end)
                                                    as open_tickets,
        sum(case when issue_type = 'billing' then 1 else 0 end)
                                                    as billing_tickets,
        sum(case when issue_type = 'delivery' then 1 else 0 end)
                                                    as delivery_tickets
    from {{ ref('stg_ret_tickets') }}
    group by b2b_customer_id
)

select
    c.b2b_customer_id,
    c.customer_name,
    c.company_name,
    c.region,
    c.customer_start_date,
    coalesce(o.total_orders, 0)                     as total_orders,
    coalesce(o.total_revenue, 0)                    as total_revenue,
    coalesce(o.cancelled_revenue, 0)                as cancelled_revenue,
    coalesce(o.cancelled_orders, 0)                 as cancelled_orders,
    coalesce(o.last_order_date, null)               as last_order_date,
    coalesce(t.total_tickets, 0)                    as total_tickets,
    coalesce(t.open_tickets, 0)                     as open_tickets,
    coalesce(t.billing_tickets, 0)                  as billing_tickets,
    coalesce(t.delivery_tickets, 0)                 as delivery_tickets,

    -- Return rate
    div0(o.cancelled_orders, o.total_orders)        as return_rate,

    -- Health score: 100 - (10 per open ticket) - (20 if >20% return rate)
    greatest(0,
        100
        - (coalesce(t.open_tickets, 0) * 10)
        - (case when div0(o.cancelled_orders, o.total_orders) > 0.2 then 20 else 0 end)
    )                                               as health_score,

    -- Risk flag
    case
        when coalesce(t.open_tickets, 0) >= 3 then 'at_risk'
        when div0(o.cancelled_orders, o.total_orders) > 0.3 then 'at_risk'
        when coalesce(t.open_tickets, 0) >= 1 then 'needs_attention'
        else 'healthy'
    end                                             as account_health_status

from b2b_customers c
left join orders o   on o.b2b_customer_id = c.b2b_customer_id
left join tickets t  on t.b2b_customer_id = c.b2b_customer_id
