/*
  int_current_customers
  =====================
  Resolves the SCD2 customers table to one row per customer_id
  (current active record only), then joins loyalty segment descriptions.

  SCD2 resolution strategy:
  - Primary: flag rows where is_current = true (valid_to = 0 or null)
  - Tiebreak: if multiple "current" rows exist per customer_id,
    take the one with the latest valid_from_date

  Demo talking point (Act 1 chaos):
    Querying CUSTOMERS directly without this resolution returns
    duplicate customer_ids, causing inflated counts and incorrect aggregations.
*/

with customers as (
    select * from {{ ref('stg_customers') }}
    where is_current = true
),

-- Deduplicate in case multiple "current" rows exist per customer_id
deduped as (
    select *,
        row_number() over (
            partition by customer_id
            order by valid_from_date desc nulls last
        ) as rn
    from customers
),

loyalty as (
    select * from {{ ref('stg_loyalty_segments') }}
)

select
    d.customer_id,
    d.customer_name,
    d.city,
    d.state,
    d.region,
    d.district,
    d.postcode,
    d.street,
    d.ship_to_address,
    d.lat,
    d.lon,
    d.loyalty_segment_id,
    l.loyalty_segment_description,
    l.unit_threshold                    as loyalty_unit_threshold,
    d.units_purchased,
    d.customer_number,
    d.valid_from_date                   as customer_since_date
from deduped d
left join loyalty l
    on l.loyalty_segment_id = d.loyalty_segment_id
where d.rn = 1
