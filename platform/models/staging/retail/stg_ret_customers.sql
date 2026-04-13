/*
  stg_ret_customers
  =================
  Staging for B2B retail customer accounts (100 accounts).
*/

select
    id                                              as b2b_customer_id,
    name                                            as customer_name,
    email,
    region,
    company_name,
    customer_start_date,
    _fivetran_synced
from {{ source('retail', 'ret_customers') }}
where (_fivetran_deleted is false or _fivetran_deleted is null)
