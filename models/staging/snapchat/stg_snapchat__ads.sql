{#
  stg_snapchat__ads
  GRAIN: one row per Snapchat ad.   KEY: ad_id
#}

with source as (

    select * from {{ source('snapchat_ads', 'snapchat_ads') }}

)

select
    {{ clean_string('ad_id') }}                                         as ad_id,
    {{ clean_string('ad_group_id') }}                                   as ad_group_id,
    {{ clean_string('ad_name') }}                                       as ad_name,
    try_cast({{ clean_string('ad_detail_updated_at') }} as timestamp)   as ad_updated_at,
    {{ loaded_at(source('snapchat_ads', 'snapchat_ads')) }} as _loaded_at
from source
where {{ clean_string('ad_id') }} is not null
qualify row_number() over (
    partition by {{ clean_string('ad_id') }}
    order by try_cast({{ clean_string('ad_detail_updated_at') }} as timestamp) desc
) = 1
