/*
  stg_regional_sales_targets
  ===========================
  Staging for regional sales targets seed. Monthly revenue and order
  targets by region for performance tracking.
*/

select
    region,
    target_month::date      as target_month,
    revenue_target,
    order_target,
    notes
from {{ ref('regional_sales_targets') }}
