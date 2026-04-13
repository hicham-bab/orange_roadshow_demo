/*
  stg_sales_orders
  ================
  Staging for B2C sales orders.
  Key transformations:
  - ORDER_DATETIME (epoch NUMBER) → proper timestamp + date
  - ORDERED_PRODUCTS (raw text) → parsed JSON variant for downstream use
  - Soft-deleted rows excluded
*/

select
    id                                              as order_id,
    order_number,
    customer_id,
    customer_name,

    -- Convert epoch to usable datetime
    to_timestamp(order_datetime)                    as order_timestamp,
    to_timestamp(order_datetime)::date              as order_date,

    -- Parse ORDERED_PRODUCTS into a JSON variant for FLATTEN() downstream
    -- TRY_PARSE_JSON returns NULL if not valid JSON rather than failing
    try_parse_json(ordered_products)                as ordered_products_json,

    -- Keep raw text for fallback / debugging
    ordered_products                                as ordered_products_raw,

    number_of_line_items,

    -- Parse promo info
    nullif(trim(promo_info), '')                    as promo_code,

    -- Parse clicked items (raw clickstream)
    try_parse_json(clicked_items)                   as clicked_items_json,

    _fivetran_synced
from {{ source('retail', 'sales_orders') }}
where (_fivetran_deleted is false or _fivetran_deleted is null)
