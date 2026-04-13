/*
  stg_loyalty_segments
  ====================
  Loyalty segment lookup table. 4 rows.
  Translates numeric loyalty_segment_id codes to human-readable descriptions.
*/

select
    loyalty_segment_id,
    loyalty_segment_description,
    unit_threshold,
    valid_from,
    valid_to
from {{ source('retail', 'loyalty_segments') }}
where (_fivetran_deleted is false or _fivetran_deleted is null)
