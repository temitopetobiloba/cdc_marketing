{#
  stg_facebook__ads
  GRAIN: one row per Facebook ad.   KEY: ad_id
  Links each ad to its ad group (ad set), campaign and account.
#}

with source as (

    select * from {{ source('facebook_ads', 'facebook_ads') }}

)

select
    {{ clean_string('ad_id') }}                                 as ad_id,
    {{ clean_string('ad_group_id') }}                           as ad_group_id,
    {{ clean_string('campaign_id') }}                           as campaign_id,
    {{ clean_string('account_id') }}                            as account_id,
    {{ clean_string('ad_name') }}                               as ad_name,
    lower({{ clean_string('ad_status') }})                      as ad_status,
    try_cast({{ clean_string('ad_updated_at') }} as timestamp)  as ad_updated_at,
    {{ loaded_at(source('facebook_ads', 'facebook_ads')) }} as _loaded_at
from source
where {{ clean_string('ad_id') }} is not null
qualify row_number() over (
    partition by {{ clean_string('ad_id') }}
    order by try_cast({{ clean_string('ad_updated_at') }} as timestamp) desc
) = 1
