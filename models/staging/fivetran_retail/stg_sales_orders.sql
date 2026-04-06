with source as (

    select * from {{ source('fivetran_retail', 'sales_orders') }}
    where _fivetran_deleted is null or _fivetran_deleted = false

),

renamed as (

    select
        id                                                          as order_id,
        customer_id,
        customer_name,
        order_number,
        cast(order_datetime as timestamp)                           as order_datetime,
        cast(number_of_line_items as integer)                       as number_of_line_items,
        clicked_items,
        ordered_products,
        promo_info,
        case when promo_info is not null then true else false end    as has_promo,
        _fivetran_synced

    from source

)

select * from renamed
