/*
  stg_customers
  =============
  Staging for the SCD2 B2C customers table.
  - Excludes Fivetran soft-deleted rows
  - Converts VALID_FROM / VALID_TO epoch numbers to timestamps
  - Identifies current active records (VALID_TO = 0 or NULL)
  - Does NOT filter to current records here — use int_current_customers for that
*/

select
    id                                              as surrogate_id,
    customer_id,
    customer_name,
    city,
    state,
    region,
    district,
    postcode,
    street,
    ship_to_address,
    lat,
    lon,
    loyalty_segment                                 as loyalty_segment_id,
    units_purchased,
    unit,
    number                                          as customer_number,
    tax_id,
    tax_code,

    -- Convert epoch to timestamp (VALID_FROM = 0 means no start restriction)
    case
        when valid_from = 0 or valid_from is null then null
        else to_timestamp(valid_from)::date
    end                                             as valid_from_date,

    -- VALID_TO = 0 means current active record
    case
        when valid_to = 0 or valid_to is null then null
        else to_timestamp(valid_to)::date
    end                                             as valid_to_date,

    -- Flag current active record
    (valid_to = 0 or valid_to is null)              as is_current,

    _fivetran_synced
from {{ source('retail', 'customers') }}
where (not _fivetran_deleted or _fivetran_deleted is null)
