with orders as (

    select * from {{ ref('stg_ret_orders') }}

),

customers as (

    select * from {{ ref('stg_ret_customers') }}

),

enriched as (

    select
        o.order_id,
        o.customer_id,
        o.amount,
        o.status,
        o.created_at,
        o.cancel_return_reason,
        c.name,
        c.company_name,
        c.region,
        c.customer_start_date

    from orders o
    left join customers c
        on o.customer_id = c.customer_id

)

select * from enriched
