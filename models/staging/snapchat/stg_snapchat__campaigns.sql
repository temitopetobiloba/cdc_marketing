{#
  stg_snapchat__campaigns
  GRAIN: one row per Snapchat campaign.   KEY: campaign_id
  Snapchat has no account table, so account_id lives here.
#}

with source as (

    select * from {{ source('snapchat_ads', 'snapchat_campaigns') }}

)

select
    {{ clean_string('campaign_id') }}       as campaign_id,
    {{ clean_string('account_id') }}        as account_id,
    {{ clean_string('campaign_name') }}     as campaign_name,
    {{ loaded_at(source('snapchat_ads', 'snapchat_campaigns')) }} as _loaded_at
from source
where {{ clean_string('campaign_id') }} is not null
qualify row_number() over (
    partition by {{ clean_string('campaign_id') }}
    order by campaign_id
) = 1
