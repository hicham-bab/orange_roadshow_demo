with enriched as (

    select * from {{ ref('int_customers_enriched') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }}    as customer_key,
        customer_id,
        customer_name,
        city,
        region,
        state,
        lat,
        lon,
        loyalty_segment,
        loyalty_segment_description,
        unit_threshold,
        units_purchased,
        valid_from,
        valid_to,
        ship_to_address,
        case
            when valid_to is null then true
            when valid_to >= cast(current_date as date) then true
            else false
        end                                                        as is_active

    from enriched

)

select * from final
