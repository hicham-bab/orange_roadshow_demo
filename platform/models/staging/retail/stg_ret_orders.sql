/*
  stg_ret_orders
  ==============
  Staging for B2B retail orders. AMOUNT is a clean numeric field.
*/

select
    id                                              as order_id,
    order_user_id                                   as b2b_customer_id,
    amount,
    status,
    nullif(trim(cancel_return_reason), '')          as cancel_return_reason,
    created_at,
    created_at::date                                as order_date,
    _fivetran_synced
from {{ source('retail', 'ret_orders') }}
where (not _fivetran_deleted or _fivetran_deleted is null)
