{#
  mart_campaign_performance_daily  — the analyst / BI / AI-agent table
  --------------------------------------------------------------------
  GRAIN: one row = ONE campaign, on ONE platform, on ONE day.
  PK:    campaign_day_id = hash(campaign_key, date_day)

  The "data product": wide, self-explanatory, no joins needed.
  Money is reported in EUR (spend_eur) so platforms and accounts compare fairly;
  spend_local keeps the original-currency amount.

  Ratios (CTR, CPC, CPM) are computed here AFTER summing to campaign-day.
  When you roll up further (month, platform) RE-COMPUTE them from the sums:
      CPC = sum(spend_eur) / sum(clicks)     -- correct
      avg(cpc)                               -- WRONG

  TABLE: the most-queried object (dashboards, ad-hoc, agents), so it is
  computed once per run instead of on every query.
#}

with daily_ads as (

    select * from {{ ref('fct_ad_performance_daily') }}

),

campaigns as (

    select * from {{ ref('dim_campaigns') }}

),

campaign_day as (

    select
        campaign_key,
        date_day,
        platform,
        count(distinct ad_id)                   as active_ads,
        count(distinct country_code)            as countries,
        sum(spend)                              as spend_local,
        sum(spend_eur)                          as spend_eur,
        sum(impressions)                        as impressions,
        sum(clicks)                             as clicks,
        max(cast(is_clicks_missing as int)) = 1 as has_imputed_clicks
    from daily_ads
    group by campaign_key, date_day, platform

)

select
    {{ dbt_utils.generate_surrogate_key(['campaign_day.campaign_key', 'campaign_day.date_day']) }}
                                                        as campaign_day_id,

    -- when
    campaign_day.date_day,
    cast(date_trunc('week',  campaign_day.date_day) as date)   as week_start_date,
    cast(date_trunc('month', campaign_day.date_day) as date)   as month_start_date,
    year(campaign_day.date_day)                                as year,

    -- who / what
    campaign_day.platform,
    campaign_day.campaign_key,
    campaigns.campaign_id,
    campaigns.campaign_name,
    campaigns.account_id,
    campaigns.account_name,
    campaigns.currency_code                             as local_currency_code,
    campaign_day.active_ads,
    campaign_day.countries,

    -- additive measures (safe to SUM)
    campaign_day.spend_eur,
    campaign_day.spend_local,
    campaign_day.impressions,
    campaign_day.clicks,

    -- ratio metrics in EUR (re-compute from sums when aggregating further!)
    {{ safe_divide('campaign_day.clicks', 'campaign_day.impressions') }}         as ctr,
    {{ safe_divide('campaign_day.spend_eur', 'campaign_day.clicks') }}           as cpc_eur,
    {{ safe_divide('campaign_day.spend_eur * 1000', 'campaign_day.impressions') }} as cpm_eur,

    campaign_day.has_imputed_clicks

from campaign_day
left join campaigns
    on campaign_day.campaign_key = campaigns.campaign_key
