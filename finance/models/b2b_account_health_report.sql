/*
  b2b_account_health_report
  =========================
  Cross-project consumption: finance team's view of B2B account risk.
  Used for AR provisioning, credit reviews, and revenue forecasting.
*/

with accounts as (
    select * from {{ ref('fretwork_guitars', 'dim_b2b_customers') }}
),

orders as (
    select
        b2b_customer_id,
        count(*)                                            as recent_orders,
        sum(amount)                                         as recent_revenue,
        sum(case when is_cancelled_or_returned then amount else 0 end) as recent_cancelled
    from {{ ref('fretwork_guitars', 'fct_b2b_orders') }}
    where order_date >= dateadd('month', -6, current_date)
    group by b2b_customer_id
)

select
    a.b2b_customer_id,
    a.company_name,
    a.region,
    a.customer_start_date,
    a.total_revenue         as lifetime_revenue,
    a.total_orders          as lifetime_orders,
    a.health_score,
    a.account_health_status,
    a.open_tickets,
    a.return_rate,

    -- Recent 6-month activity
    coalesce(o.recent_orders, 0)    as orders_last_6m,
    coalesce(o.recent_revenue, 0)   as revenue_last_6m,
    coalesce(o.recent_cancelled, 0) as cancelled_last_6m,

    -- Finance risk classification
    case
        when a.account_health_status = 'at_risk' and a.open_tickets >= 3
            then 'high_risk'
        when a.account_health_status = 'at_risk'
            then 'elevated_risk'
        when a.account_health_status = 'needs_attention'
            then 'monitor'
        else 'standard'
    end as finance_risk_tier

from accounts a
left join orders o on o.b2b_customer_id = a.b2b_customer_id
