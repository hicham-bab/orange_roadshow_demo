with source as (

    select * from {{ source('fivetran_retail', 'ret_orders') }}
    where _fivetran_deleted is null or _fivetran_deleted = false

),

renamed as (

    select
        id                                         as order_id,
        order_user_id                              as customer_id,
        cast(amount as numeric(18, 2))             as amount,
        status,
        created_at,
        cancel_return_reason,
        _fivetran_synced

    from source

)

select * from renamed
