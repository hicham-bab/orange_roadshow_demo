with source as (

    select * from {{ source('fivetran_retail', 'loyalty_segments') }}
    where _fivetran_deleted is null or _fivetran_deleted = false

),

renamed as (

    select
        loyalty_segment_id,
        loyalty_segment_description,
        cast(unit_threshold as numeric)        as unit_threshold,
        valid_from,
        valid_to,
        _fivetran_synced

    from source

)

select * from renamed
