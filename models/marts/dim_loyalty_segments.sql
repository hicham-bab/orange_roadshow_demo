with segments as (

    select * from {{ ref('stg_loyalty_segments') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['loyalty_segment_id']) }}    as loyalty_segment_key,
        loyalty_segment_id,
        loyalty_segment_description,
        unit_threshold,
        valid_from,
        valid_to,
        case
            when valid_to is null then true
            when valid_to >= cast(current_date as date) then true
            else false
        end                                                               as is_current

    from segments

)

select * from final
