{#
  stg_facebook__campaigns
  GRAIN: one row per Facebook campaign.   KEY: campaign_id
#}

with source as (

    select * from {{ source('facebook_ads', 'facebook_campaigns') }}

)

select
    {{ clean_string('campaign_id') }}                                   as campaign_id,
    {{ clean_string('campaign_name') }}                                 as campaign_name,
    try_cast({{ clean_string('campaign_updated_at') }} as timestamp)    as campaign_updated_at,
    {{ loaded_at(source('facebook_ads', 'facebook_campaigns')) }} as _loaded_at
from source
where {{ clean_string('campaign_id') }} is not null
qualify row_number() over (
    partition by {{ clean_string('campaign_id') }}
    order by try_cast({{ clean_string('campaign_updated_at') }} as timestamp) desc
) = 1
