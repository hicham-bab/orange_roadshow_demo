/*
  rpt_promo_effectiveness
  ========================
  Campaign-level performance report. Joins B2C orders to promo campaign
  definitions to measure promotion ROI.

  Great demo model: Cortex Analyst can answer "which campaign had the
  best ROI?" or "how much revenue did the Spring launch drive?"
*/

with promo_orders as (
    select
        o.order_id,
        o.order_date,
        o.customer_id,
        o.promo_code,
        o.total_revenue,
        o.number_of_line_items
    from {{ ref('fct_sales_orders') }} o
    where o.has_promo = true
),

campaigns as (
    select * from {{ ref('stg_promo_campaigns') }}
)

select
    c.promo_code,
    c.campaign_name,
    c.campaign_type,
    c.discount_pct,
    c.target_channel,
    c.start_date                                as campaign_start,
    c.end_date                                  as campaign_end,
    c.budget_usd                                as campaign_budget,
    count(distinct po.order_id)                 as total_orders,
    count(distinct po.customer_id)              as unique_customers,
    coalesce(sum(po.total_revenue), 0)          as gross_revenue,
    coalesce(sum(po.number_of_line_items), 0)   as total_items_sold,
    coalesce(avg(po.total_revenue), 0)          as avg_order_value,

    -- ROI = (revenue - budget) / budget
    case
        when c.budget_usd > 0
        then round((coalesce(sum(po.total_revenue), 0) - c.budget_usd)
                    / c.budget_usd * 100, 1)
    end                                         as campaign_roi_pct,

    -- Revenue per dollar spent
    case
        when c.budget_usd > 0
        then round(coalesce(sum(po.total_revenue), 0)
                   / c.budget_usd, 2)
    end                                         as revenue_per_dollar_spent

from campaigns c
left join promo_orders po
    on po.promo_code = c.promo_code
   and po.order_date between c.start_date and c.end_date
group by
    c.promo_code, c.campaign_name, c.campaign_type,
    c.discount_pct, c.target_channel,
    c.start_date, c.end_date, c.budget_usd
