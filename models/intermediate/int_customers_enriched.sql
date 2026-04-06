with customers as (

    select * from {{ ref('stg_customers') }}

),

loyalty_segments as (

    select * from {{ ref('stg_loyalty_segments') }}

),

enriched as (

    select
        c.customer_id,
        c.customer_name,
        c.city,
        c.region,
        c.state,
        c.lat,
        c.lon,
        c.loyalty_segment,
        ls.loyalty_segment_description,
        ls.unit_threshold,
        c.units_purchased,
        c.valid_from,
        c.valid_to,
        c.ship_to_address

    from customers c
    left join loyalty_segments ls
        on c.loyalty_segment = ls.loyalty_segment_id

)

select * from enriched
