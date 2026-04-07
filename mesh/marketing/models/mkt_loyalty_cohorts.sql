with customers as (

    select
        customer_id,
        loyalty_segment,
        loyalty_segment_description,
        unit_threshold,
        units_purchased,
        is_active
    from {{ ref('retail_demo', 'dim_customers') }}

),

segments as (

    select
        loyalty_segment_id,
        loyalty_segment_description,
        unit_threshold
    from {{ ref('retail_demo', 'dim_loyalty_segments') }}

),

cohorts as (

    select
        c.loyalty_segment,
        c.loyalty_segment_description,
        c.unit_threshold,
        count(distinct c.customer_id)                                           as customer_count,
        cast(avg(c.units_purchased) as number)                                  as avg_units_purchased,
        cast(
            count(case when c.is_active = true then 1 end) * 100.0
            / nullif(count(c.customer_id), 0)
            as number
        )                                                                        as pct_active
    from customers c
    group by
        c.loyalty_segment,
        c.loyalty_segment_description,
        c.unit_threshold

)

select
    loyalty_segment,
    loyalty_segment_description,
    unit_threshold,
    customer_count,
    avg_units_purchased,
    pct_active
from cohorts
order by unit_threshold desc
