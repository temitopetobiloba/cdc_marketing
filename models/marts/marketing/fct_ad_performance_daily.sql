{#
  fct_ad_performance_daily  — the core FACT table
  ------------------------------------------------
  GRAIN: one row = ONE ad, on ONE platform, on ONE day, in ONE country.
         (Facebook has no country split: country_code is NULL for Facebook.)
  PK:    ad_performance_id  = hash(platform, ad_id, date_day, country_code)
  FK:    campaign_key       -> dim_campaigns.campaign_key

  Holds only ADDITIVE measures (spend, spend_eur, impressions, clicks), which
  can be summed to any level. Ratios (CTR, CPC, CPM) are computed after
  aggregation in mart_campaign_performance_daily.

  Why INCREMENTAL (merge)?
    * The only table that grows every day, forever.
    * Each run re-processes the last N days (ad platforms revise recent days)
      plus any rows loaded since the last run (catches backfills).
    * MERGE on the key: re-processed rows are UPDATED, never duplicated.
    * Changed the logic?  dbt build --full-refresh -s fct_ad_performance_daily
#}

{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = 'ad_performance_id',
        on_schema_change = 'append_new_columns',
        liquid_clustered_by = ['date_day', 'platform']
    )
}}

with ad_performance as (

    select * from {{ ref('int_ad_performance__unioned') }}

    {% if is_incremental() %}
    where date_day >= (
              select date_sub(max(date_day), {{ var('incremental_lookback_days') }})
              from {{ this }}
          )
       or _loaded_at > (select max(source_loaded_at) from {{ this }})
    {% endif %}

)

select
    ad_performance_id,
    {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }} as campaign_key,

    -- when / where
    date_day,
    platform,
    country_code,

    -- hierarchy (ids + names kept for ad-level drill-down)
    account_id,
    campaign_id,
    ad_group_id,
    ad_group_name,
    ad_id,
    ad_name,
    ad_status,

    -- measures (additive)
    currency_code,
    spend,                      -- in currency_code
    rate_to_eur,
    spend_eur,                  -- use this to compare or add up across accounts
    impressions,
    clicks,

    -- data-quality flags
    is_impressions_missing,
    is_clicks_missing,

    _loaded_at              as source_loaded_at,
    current_timestamp()     as dbt_updated_at

from ad_performance
