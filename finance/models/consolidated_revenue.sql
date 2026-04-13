/*
  consolidated_revenue
  ====================
  Cross-project consumption from the core platform project.
  Unified B2C + B2B revenue view for financial reporting and forecasting.

  This model demonstrates dbt Mesh: the finance team builds on top of
  governed, contracted marts without redefining revenue logic.
*/

with b2c_revenue as (
    select
        order_date,
        order_id,
        customer_id::varchar    as account_id,
        total_revenue           as revenue,
        has_promo,
        'B2C'                   as channel,
        false                   as is_cancelled_or_returned
    from {{ ref('harmony_central_data', 'fct_sales_orders') }}
),

b2b_revenue as (
    select
        order_date,
        order_id,
        b2b_customer_id         as account_id,
        amount                  as revenue,
        false                   as has_promo,
        'B2B'                   as channel,
        is_cancelled_or_returned
    from {{ ref('harmony_central_data', 'fct_b2b_orders') }}
)

select
    order_date,
    date_trunc('month', order_date)     as fiscal_month,
    date_trunc('quarter', order_date)   as fiscal_quarter,
    order_id,
    account_id,
    channel,
    revenue,
    has_promo,
    is_cancelled_or_returned,

    -- Net revenue excludes cancellations/returns
    case
        when is_cancelled_or_returned then 0
        else revenue
    end as net_revenue

from b2c_revenue
union all
select
    order_date,
    date_trunc('month', order_date)     as fiscal_month,
    date_trunc('quarter', order_date)   as fiscal_quarter,
    order_id,
    account_id,
    channel,
    revenue,
    has_promo,
    is_cancelled_or_returned,
    case
        when is_cancelled_or_returned then 0
        else revenue
    end as net_revenue
from b2b_revenue
