-- Test: all B2C orders must have non-negative total_revenue
-- Fails if any order has total_revenue < 0

select order_id, total_revenue
from {{ ref('fct_sales_orders') }}
where total_revenue < 0
