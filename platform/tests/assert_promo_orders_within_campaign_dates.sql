-- Test: promo effectiveness report should not count orders outside campaign windows
-- Fails if any campaign has orders falling outside its start/end date range

select
    r.promo_code,
    o.order_id,
    o.order_date,
    r.campaign_start,
    r.campaign_end
from {{ ref('fct_sales_orders') }} o
inner join {{ ref('rpt_promo_effectiveness') }} r
    on o.promo_code = r.promo_code
where o.has_promo = true
  and o.order_date not between r.campaign_start and r.campaign_end
  and r.total_orders > 0
