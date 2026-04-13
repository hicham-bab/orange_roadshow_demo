/*
  dim_b2b_customers
  =================
  B2B account dimension with health scoring and order/ticket metrics.
*/

select
    b2b_customer_id,
    customer_name,
    company_name,
    region,
    customer_start_date,
    total_orders,
    total_revenue,
    cancelled_revenue,
    cancelled_orders,
    last_order_date,
    total_tickets,
    open_tickets,
    billing_tickets,
    delivery_tickets,
    return_rate,
    health_score,
    account_health_status
from {{ ref('int_b2b_customer_health') }}
