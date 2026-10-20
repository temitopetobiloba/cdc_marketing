-- =============================================================================
-- Answers to the brief's business questions, against the final mart.
-- `dbt compile` writes runnable SQL to target/compiled/cdc_marketing/analyses/.
-- Or paste into Databricks, replacing each ref() with the full table name,
-- e.g. third_layer.marketing_marts.mart_campaign_performance_daily (dev).
--
-- Rule: SUM the measures, THEN divide. Never average ctr / cpc_eur / cpm_eur.
-- Note: Facebook data covers 2025, Snapchat 2024. Platform comparisons are
-- across different years; say so when presenting them.
-- =============================================================================

-- 1. Total spend, and spend per platform, with blended KPIs (EUR)
select
    coalesce(platform, 'TOTAL')                                 as platform,
    min(date_day)                                               as first_day,
    max(date_day)                                               as last_day,
    round(sum(spend_eur), 2)                                    as spend_eur,
    sum(impressions)                                            as impressions,
    sum(clicks)                                                 as clicks,
    round(sum(clicks) / nullif(sum(impressions), 0), 5)         as ctr,
    round(sum(spend_eur) / nullif(sum(clicks), 0), 2)           as cpc_eur,
    round(sum(spend_eur) * 1000 / nullif(sum(impressions), 0), 2) as cpm_eur
from {{ ref('mart_campaign_performance_daily') }}
group by rollup (platform)
order by platform nulls last;

-- 2. Spend, impressions and clicks by campaign (top 10 by impressions)
select
    platform,
    campaign_name,
    round(sum(spend_eur), 2)                            as spend_eur,
    sum(impressions)                                    as impressions,
    sum(clicks)                                         as clicks,
    round(sum(spend_eur) / nullif(sum(clicks), 0), 2)   as cpc_eur
from {{ ref('mart_campaign_performance_daily') }}
group by platform, campaign_name
order by impressions desc
limit 10;

-- 3. Campaign with the most clicks
select platform, campaign_name, sum(clicks) as clicks
from {{ ref('mart_campaign_performance_daily') }}
group by platform, campaign_name
order by clicks desc
limit 1;

-- 4. Performance over time: monthly trend per platform
select
    month_start_date,
    platform,
    round(sum(spend_eur), 2)                                    as spend_eur,
    sum(clicks)                                                 as clicks,
    round(sum(clicks) / nullif(sum(impressions), 0), 5)         as ctr,
    round(sum(spend_eur) * 1000 / nullif(sum(impressions), 0), 2) as cpm_eur
from {{ ref('mart_campaign_performance_daily') }}
group by month_start_date, platform
order by month_start_date, platform;

-- 5. "How much did we spend on Facebook last month?"
--    (relative to the latest Facebook day in the data, since the data is historical)
with latest as (
    select max(month_start_date) as last_month
    from {{ ref('mart_campaign_performance_daily') }}
    where platform = 'facebook'
)
select round(sum(spend_eur), 2) as facebook_spend_eur_last_month
from {{ ref('mart_campaign_performance_daily') }}, latest
where platform = 'facebook'
  and month_start_date = latest.last_month;

-- 6. Snapchat by country (from the fact table: the only country-level data)
select
    country_code,
    round(sum(spend_eur), 2)    as spend_eur,
    sum(impressions)            as impressions,
    sum(clicks)                 as clicks
from {{ ref('fct_ad_performance_daily') }}
where platform = 'snapchat'
group by country_code
order by spend_eur desc;
