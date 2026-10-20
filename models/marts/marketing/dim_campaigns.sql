{#
  dim_campaigns  — campaign DIMENSION
  -----------------------------------
  GRAIN: one row per campaign per platform.
  PK:    campaign_key = hash(platform, campaign_id)

  Built from the campaign tables (not from the stats), so it lists EVERY
  campaign, including those that never spent. Each campaign carries its
  account and the account's currency.

  Campaign IDs are only unique WITHIN a platform, so platform is in the key.
  Materialized as a TABLE: small (~4k rows), joined on every dashboard query,
  and a full rebuild each run keeps names current (SCD type 1).
#}

with facebook_campaign_accounts as (

    -- Facebook campaigns don't store their account; read it from their ads.
    -- (Verified: no Facebook campaign spans more than one account.)
    select distinct campaign_id, account_id
    from {{ ref('stg_facebook__ads') }}

),

facebook as (

    select
        'facebook'                      as platform,
        campaigns.campaign_id,
        campaigns.campaign_name,
        links.account_id,
        accounts.account_name,
        accounts.currency_code
    from {{ ref('stg_facebook__campaigns') }} as campaigns
    left join facebook_campaign_accounts as links
        on campaigns.campaign_id = links.campaign_id
    left join {{ ref('stg_facebook__accounts') }} as accounts
        on links.account_id = accounts.account_id

),

snapchat as (

    select
        'snapchat'                      as platform,
        campaign_id,
        campaign_name,
        account_id,
        'Snapchat account ' || left(account_id, 8) as account_name,
        'EUR'                           as currency_code
    from {{ ref('stg_snapchat__campaigns') }}

),

all_campaigns as (

    select * from facebook
    union all
    select * from snapchat

),

activity as (

    select
        platform,
        campaign_id,
        min(date_day)       as first_active_date,
        max(date_day)       as last_active_date,
        sum(spend_eur)      as lifetime_spend_eur
    from {{ ref('fct_ad_performance_daily') }}
    group by platform, campaign_id

)

select
    {{ dbt_utils.generate_surrogate_key(['all_campaigns.platform', 'all_campaigns.campaign_id']) }}
                                        as campaign_key,
    all_campaigns.platform,
    all_campaigns.campaign_id,
    coalesce(all_campaigns.campaign_name, 'Unknown campaign (' || all_campaigns.campaign_id || ')')
                                        as campaign_name,
    all_campaigns.account_id,
    all_campaigns.account_name,
    all_campaigns.currency_code,
    activity.first_active_date,
    activity.last_active_date,
    coalesce(activity.lifetime_spend_eur, 0) as lifetime_spend_eur,
    activity.campaign_id is not null    as has_delivery
from all_campaigns
left join activity
    on  all_campaigns.platform    = activity.platform
    and all_campaigns.campaign_id = activity.campaign_id
