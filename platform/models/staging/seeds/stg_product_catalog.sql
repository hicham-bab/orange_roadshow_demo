/*
  stg_product_catalog
  ====================
  Staging for product catalog seed. Reference data for product enrichment.
*/

select
    product_id,
    product_name,
    category,
    subcategory,
    unit_cost::number(12, 2)                    as unit_cost,
    launch_date,
    is_active
from {{ ref('product_catalog') }}
where is_active = true
