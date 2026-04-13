-- Test: dim_customers must have exactly one row per customer_id
-- A failure here means the SCD2 resolution in int_current_customers broke

select customer_id, count(*) as row_count
from {{ ref('dim_customers') }}
group by customer_id
having count(*) > 1
