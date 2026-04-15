/*
  regional_target_attainment
  ===========================
  Compares actual regional sales performance against monthly targets.
  Identifies underperforming regions for campaign intervention.

  Uses local regional_performance model and cross-project reference
  to the platform's regional targets dimension.
*/

with actuals as (
    select
        region,
        order_month,
        total_orders,
        monthly_revenue
    from {{ ref('regional_performance') }}
),

targets as (
    select
        region,
        target_month,
        revenue_target,
        order_target
    from {{ ref('harmony_central_data', 'dim_regional_sales_targets') }}
)

select
    coalesce(a.region, t.region)                    as region,
    coalesce(a.order_month, t.target_month)         as month,
    coalesce(a.total_orders, 0)                     as actual_orders,
    coalesce(t.order_target, 0)                     as target_orders,
    coalesce(a.monthly_revenue, 0)                  as actual_revenue,
    coalesce(t.revenue_target, 0)                   as target_revenue,

    -- Attainment percentages
    case
        when t.revenue_target > 0
        then round(a.monthly_revenue / t.revenue_target * 100, 1)
    end                                             as revenue_attainment_pct,

    case
        when t.order_target > 0
        then round(a.total_orders::numeric / t.order_target * 100, 1)
    end                                             as order_attainment_pct,

    -- Gap analysis
    coalesce(a.monthly_revenue, 0) - coalesce(t.revenue_target, 0)
                                                    as revenue_gap,

    -- Performance flag
    case
        when t.revenue_target is null then 'no_target'
        when a.monthly_revenue >= t.revenue_target then 'on_track'
        when a.monthly_revenue >= t.revenue_target * 0.8 then 'at_risk'
        else 'behind'
    end                                             as performance_status

from actuals a
full outer join targets t
    on a.region = t.region
   and a.order_month = t.target_month
