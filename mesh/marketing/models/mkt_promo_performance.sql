with b2c_orders as (

    select
        order_key,
        has_promo,
        number_of_line_items
    from {{ ref('retail_demo', 'fct_orders') }}
    where order_type = 'b2c'

),

total_count as (

    select count(order_key) as total_orders
    from b2c_orders

),

aggregated as (

    select
        o.has_promo,
        count(o.order_key)                                                       as order_count,
        cast(avg(o.number_of_line_items) as number)                             as avg_line_items
    from b2c_orders o
    group by o.has_promo

)

select
    a.has_promo,
    a.order_count,
    a.avg_line_items,
    cast(a.order_count * 100.0 / nullif(t.total_orders, 0) as number)          as pct_of_total_orders
from aggregated a
cross join total_count t
order by a.has_promo desc
