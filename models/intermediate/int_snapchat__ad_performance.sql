{#
  int_snapchat__ad_performance
  GRAIN: one row per Snapchat ad, per day, per country.

  Same output contract as int_facebook__ad_performance.
  Snapchat's hierarchy is reached in a different order than Facebook's:
      stats -> ad -> ad group -> campaign -> account_id
  (Facebook ads point straight at their campaign; Snapchat ads only know
  their ad group, which knows the campaign.)
  There is no Snapchat account table, so a readable placeholder name is built.
#}

with stats as (

    select * from {{ ref('stg_snapchat__ad_stats') }}

),

ads as (

    select * from {{ ref('stg_snapchat__ads') }}

),

ad_groups as (

    select * from {{ ref('stg_snapchat__ad_groups') }}

),

campaigns as (

    select * from {{ ref('stg_snapchat__campaigns') }}

)

select
    'snapchat'                      as platform,
    stats.date_day,
    stats.country_code,

    campaigns.account_id,
    'Snapchat account ' || left(campaigns.account_id, 8) as account_name,
    ad_groups.campaign_id,
    campaigns.campaign_name,
    ads.ad_group_id,
    ad_groups.ad_group_name,
    stats.ad_id,
    ads.ad_name,
    cast(null as string)            as ad_status,      -- not in the Snapchat export

    stats.currency_code,
    stats.spend,
    stats.impressions,
    stats.clicks,
    stats.is_impressions_missing,
    stats.is_clicks_missing,

    stats._loaded_at

from stats
left join ads        on stats.ad_id = ads.ad_id
left join ad_groups  on ads.ad_group_id = ad_groups.ad_group_id
left join campaigns  on ad_groups.campaign_id = campaigns.campaign_id
