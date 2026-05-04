/*
  dim_customers
  =============
  B2C customer dimension. One row per customer_id (current SCD2 record).
  SCD2 resolution and loyalty join handled in int_current_customers.
*/

with customers as (
    select * from {{ ref('int_current_customers') }}
),

-- Compute value segment percentiles
ranked as (
    select
        *,
        percent_rank() over (order by units_purchased desc) as pct_rank
    from customers
)

select
    customer_id,
    customer_name,
    region,
    state,
    city,
    district,
    postcode,
    ship_to_address,
    lat,
    lon,
    loyalty_segment_id,
    loyalty_segment_description,
    loyalty_unit_threshold,
    units_purchased,
    customer_since_date,
    customer_number,

    -- Value segment based on units purchased percentile
    case
        when pct_rank <= 0.20 then 'high_value'
        when pct_rank <= 1.00 then 'mid_value'
        else                       'low_value'
    end                         as customer_value_segment

from ranked
