/*
  stg_promo_campaigns
  ====================
  Staging for promo campaign seed. Reference data for promotion analysis.
*/

select
    promo_code,
    campaign_name,
    discount_pct,
    campaign_type,
    start_date,
    end_date,
    target_channel,
    budget_usd
from {{ ref('promo_campaigns') }}
