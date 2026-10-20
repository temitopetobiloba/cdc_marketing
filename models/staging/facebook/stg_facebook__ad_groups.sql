{#
  stg_facebook__ad_groups
  GRAIN: one row per Facebook ad set.   KEY: ad_group_id
  Facebook calls this level an "ad set"; we use the neutral term "ad group".
#}

with source as (

    select * from {{ source('facebook_ads', 'facebook_ad_groups') }}

)

select
    {{ clean_string('ad_group_id') }}                                   as ad_group_id,
    {{ clean_string('ad_group_name') }}                                 as ad_group_name,
    try_cast({{ clean_string('ad_group_updated_at') }} as timestamp)    as ad_group_updated_at,
    {{ loaded_at(source('facebook_ads', 'facebook_ad_groups')) }} as _loaded_at
from source
where {{ clean_string('ad_group_id') }} is not null
qualify row_number() over (
    partition by {{ clean_string('ad_group_id') }}
    order by try_cast({{ clean_string('ad_group_updated_at') }} as timestamp) desc
) = 1
