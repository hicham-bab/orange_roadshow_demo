with source as (

    select * from {{ source('fivetran_retail', 'ret_customers') }}
    where _fivetran_deleted is null or _fivetran_deleted = false

),

renamed as (

    select
        id                                         as customer_id,
        name,
        company_name,
        email,
        region,
        cast(customer_start_date as date)          as customer_start_date,
        _fivetran_synced

    from source

)

select * from renamed
