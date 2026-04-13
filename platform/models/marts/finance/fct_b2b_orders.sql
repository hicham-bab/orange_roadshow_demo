/*
  fct_b2b_orders
  ==============
  B2B retail order fact table. Clean AMOUNT field from source.
*/

select
    order_id,
    b2b_customer_id,
    order_date,
    amount,
    status,
    status in ('cancelled', 'returned')     as is_cancelled_or_returned,
    cancel_return_reason
from {{ ref('stg_ret_orders') }}
