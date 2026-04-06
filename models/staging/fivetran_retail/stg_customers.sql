with source as (

    select * from {{ source('fivetran_retail', 'customers') }}
    where _fivetran_deleted is null or _fivetran_deleted = false

),

renamed as (

    select
        customer_id,
        customer_name,
        city,
        district,
        state,
        upper(region)                          as region,
        postcode,
        street,
        unit,
        number,
        cast(lat as float)                     as lat,
        cast(lon as float)                     as lon,
        ship_to_address,
        loyalty_segment,
        cast(units_purchased as integer)       as units_purchased,
        tax_code,
        tax_id,
        valid_from,
        valid_to,
        _fivetran_synced

    from source

)

select * from renamed
