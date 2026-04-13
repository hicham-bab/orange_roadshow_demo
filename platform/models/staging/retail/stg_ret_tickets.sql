/*
  stg_ret_tickets
  ===============
  Staging for B2B customer support tickets.
*/

select
    id                                              as ticket_id,
    ticket_user_id                                  as b2b_customer_id,
    issue_type,
    status,
    created_at,
    created_at::date                                as ticket_date,
    _fivetran_synced
from {{ source('retail', 'ret_tickets') }}
where (_fivetran_deleted is false or _fivetran_deleted is null)
