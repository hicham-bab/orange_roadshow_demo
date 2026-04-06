with b2b_orders as (

    select
        cast(order_id as varchar)                                       as order_id,
        cast(customer_id as varchar)                                    as customer_id,
        name                                                            as customer_name,
        created_at                                                      as order_date,
        amount                                                          as order_amount,
        status                                                          as order_status,
        'b2b'                                                           as order_type,
        null                                                            as number_of_line_items,
        false                                                           as has_promo,
        cancel_return_reason,
        region

    from {{ ref('int_ret_orders_with_customers') }}

),

b2c_orders as (

    select
        cast(order_id as varchar)                                       as order_id,
        cast(customer_id as varchar)                                    as customer_id,
        customer_name,
        order_datetime                                                  as order_date,
        cast(null as numeric(18, 2))                                    as order_amount,
        'completed'                                                     as order_status,
        'b2c'                                                           as order_type,
        number_of_line_items,
        has_promo,
        cast(null as varchar)                                           as cancel_return_reason,
        cast(null as varchar)                                           as region

    from {{ ref('stg_sales_orders') }}

),

unioned as (

    select * from b2b_orders
    union all
    select * from b2c_orders

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['order_id', 'order_type']) }}    as order_key,
        order_id,
        customer_id,
        customer_name,
        order_date,
        order_amount,
        order_status,
        order_type,
        number_of_line_items,
        has_promo,
        cancel_return_reason,
        region

    from unioned

)

select * from final
