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

promo_order_daily as (
    select
        po.promo_code,
        po.order_date,
        count(*) as total_orders,
        count(distinct po.customer_id) as unique_customers,
        sum(po.total_revenue) as gross_revenue,
        sum(po.number_of_line_items) as total_items_sold
    from promo_orders po
    group by
        po.promo_code,
        po.order_date
),

campaigns as (
    select
        promo_code,
        campaign_name,
        campaign_type,
        discount_pct,
        target_channel,
        start_date,
        end_date,
        budget_usd
    from {{ ref('stg_promo_campaigns') }}
)

select
    c.promo_code,
    c.campaign_name,
    c.campaign_type,
    c.discount_pct,
    c.target_channel,
    c.start_date as campaign_start,
    c.end_date as campaign_end,
    c.budget_usd as campaign_budget,
    coalesce(sum(pod.total_orders), 0) as total_orders,
    coalesce(sum(pod.unique_customers), 0) as unique_customers,
    coalesce(sum(pod.gross_revenue), 0.00) as gross_revenue,
    coalesce(sum(pod.total_items_sold), 0) as total_items_sold,
    coalesce(
        sum(pod.gross_revenue) / nullif(sum(pod.total_orders), 0),
        0
    ) as avg_order_value,

    -- ROI = (revenue - budget) / budget
    case
        when c.budget_usd > 0
            then round((coalesce(sum(pod.gross_revenue), 0) - c.budget_usd) / c.budget_usd * 100, 1)
    end as campaign_roi_pct,

    -- Revenue per dollar spent
    case
        when c.budget_usd > 0
            then round(coalesce(sum(pod.gross_revenue), 0) / c.budget_usd, 2)
    end as revenue_per_dollar_spent

from campaigns c
left join promo_order_daily pod
    on pod.promo_code = c.promo_code
   and pod.order_date between c.start_date and c.end_date
group by
    c.promo_code,
    c.campaign_name,
    c.campaign_type,
    c.discount_pct,
    c.target_channel,
    c.start_date,
    c.end_date,
    c.budget_usd
