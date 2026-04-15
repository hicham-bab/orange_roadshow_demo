/*
  dim_regional_sales_targets
  ===========================
  Regional sales targets dimension. Monthly revenue and order targets
  by region for H1 2026. Public model for cross-project consumption.
*/

select
    region,
    target_month,
    revenue_target,
    order_target,
    notes
from {{ ref('stg_regional_sales_targets') }}
