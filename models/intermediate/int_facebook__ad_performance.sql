{#
  int_facebook__ad_performance
  GRAIN: one row per Facebook ad per day (same as stg_facebook__ad_stats).

  Joins the daily stats to the rest of the hierarchy so every row knows its
  ad name, ad group, campaign, account and CURRENCY, and outputs the shared
  column contract used by every platform (see int_snapchat__ad_performance).

  LEFT joins on purpose: a missing name must never make spend disappear.
  The relationships tests in staging tell us if anything is missing.
#}

with stats as (

    select * from {{ ref('stg_facebook__ad_stats') }}

),

ads as (

    select * from {{ ref('stg_facebook__ads') }}

),

ad_groups as (

    select * from {{ ref('stg_facebook__ad_groups') }}

),

campaigns as (

    select * from {{ ref('stg_facebook__campaigns') }}

),

accounts as (

    select * from {{ ref('stg_facebook__accounts') }}

)

select
    'facebook'                      as platform,
    stats.date_day,
    cast(null as string)            as country_code,   -- Facebook export has no country split

    stats.account_id,
    accounts.account_name,
    ads.campaign_id,
    campaigns.campaign_name,
    ads.ad_group_id,
    ad_groups.ad_group_name,
    stats.ad_id,
    ads.ad_name,
    ads.ad_status,

    coalesce(accounts.currency_code, 'EUR') as currency_code,
    stats.spend,
    stats.impressions,
    stats.clicks,
    stats.is_impressions_missing,
    stats.is_clicks_missing,

    stats._loaded_at

from stats
left join ads        on stats.ad_id = ads.ad_id
left join ad_groups  on ads.ad_group_id = ad_groups.ad_group_id
left join campaigns  on ads.campaign_id = campaigns.campaign_id
left join accounts   on stats.account_id = accounts.account_id
