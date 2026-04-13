/*
  loyalty_campaign_targets
  ========================
  Cross-project consumption from the core platform project.
  Identifies high-value customers by loyalty tier for targeted campaigns.

  This model demonstrates dbt Mesh: the marketing team consumes governed,
  contracted models from the core data platform — without duplicating logic.
*/

with customers as (
    select * from {{ ref('fretwork_guitars', 'dim_customers') }}
),

orders as (
    select * from {{ ref('fretwork_guitars', 'fct_sales_orders') }}
),

customer_activity as (
    select
        customer_id,
        count(*)        as total_orders,
        sum(total_revenue) as lifetime_revenue,
        max(order_date)    as last_order_date
    from orders
    group by customer_id
)

select
    c.customer_id,
    c.customer_name,
    c.region,
    c.city,
    c.loyalty_segment_description   as loyalty_tier,
    c.customer_value_segment        as value_segment,
    c.units_purchased,
    a.total_orders,
    a.lifetime_revenue,
    a.last_order_date,
    datediff('day', a.last_order_date, current_date) as days_since_last_order,

    -- Campaign targeting logic
    case
        when c.customer_value_segment = 'high_value'
             and c.loyalty_segment_description in ('Gold', 'Platinum')
            then 'vip_retention'
        when c.customer_value_segment = 'high_value'
             and c.loyalty_segment_description in ('Bronze', 'Silver')
            then 'upgrade_candidate'
        when datediff('day', a.last_order_date, current_date) > 180
            then 'win_back'
        else 'standard_nurture'
    end as campaign_segment

from customers c
left join customer_activity a on a.customer_id = c.customer_id
