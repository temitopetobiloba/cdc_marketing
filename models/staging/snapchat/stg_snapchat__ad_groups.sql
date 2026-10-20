{#
  stg_snapchat__ad_groups
  GRAIN: one row per Snapchat ad squad (CURRENT version).   KEY: ad_group_id

  The raw table is a HISTORY table: 3 ad groups appear twice, once per
  update. We keep only the most recent version (latest ad_group_updated_at),
  which is a "type 1" view of history: current state only.
#}

with source as (

    select * from {{ source('snapchat_ads', 'snapchat_ad_groups') }}

)

select
    {{ clean_string('ad_group_id') }}                                   as ad_group_id,
    {{ clean_string('campaign_id') }}                                   as campaign_id,
    {{ clean_string('ad_group_name') }}                                 as ad_group_name,
    try_cast({{ clean_string('ad_group_updated_at') }} as timestamp)    as ad_group_updated_at,
    {{ loaded_at(source('snapchat_ads', 'snapchat_ad_groups')) }} as _loaded_at
from source
where {{ clean_string('ad_group_id') }} is not null
qualify row_number() over (
    partition by {{ clean_string('ad_group_id') }}
    order by try_cast({{ clean_string('ad_group_updated_at') }} as timestamp) desc
) = 1
