-- Test: all B2C orders must reference a valid customer in dim_customers
-- Fails if customer_id not found (SCD2 not resolved correctly)

select o.order_id, o.customer_id
from {{ ref('fct_sales_orders') }} o
left join {{ ref('dim_customers') }} c on c.customer_id = o.customer_id
where c.customer_id is null
