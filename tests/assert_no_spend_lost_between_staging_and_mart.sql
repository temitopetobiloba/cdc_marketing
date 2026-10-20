{#
  SINGULAR TEST: reconciliation. Returns rows only when money goes missing.

  Total spend per platform and currency must be identical in:
    1. the cleaned staging stats   (what the platforms reported)
    2. the fact table              (after joins + union + incremental merge)
    3. the analyst mart            (after aggregation to campaign-day)
  If a join drops rows or duplicates them, the totals stop matching and the
  build fails before a marketer sees a wrong number.
#}

with staging as (

    select 'facebook' as platform, accounts.currency_code, sum(stats.spend) as spend
    from {{ ref('stg_facebook__ad_stats') }} as stats
    left join {{ ref('stg_facebook__accounts') }} as accounts
        on stats.account_id = accounts.account_id
    group by 1, 2

    union all

    select 'snapchat', currency_code, sum(spend)
    from {{ ref('stg_snapchat__ad_stats') }}
    group by 1, 2

),

fact as (

    select platform, currency_code, sum(spend) as spend
    from {{ ref('fct_ad_performance_daily') }}
    group by 1, 2

),

mart as (

    select platform, local_currency_code as currency_code, sum(spend_local) as spend
    from {{ ref('mart_campaign_performance_daily') }}
    group by 1, 2

)

select
    coalesce(staging.platform, fact.platform, mart.platform)                as platform,
    coalesce(staging.currency_code, fact.currency_code, mart.currency_code) as currency_code,
    staging.spend   as staging_spend,
    fact.spend      as fact_spend,
    mart.spend      as mart_spend
from staging
full outer join fact
    on staging.platform = fact.platform and staging.currency_code = fact.currency_code
full outer join mart
    on coalesce(staging.platform, fact.platform) = mart.platform
   and coalesce(staging.currency_code, fact.currency_code) = mart.currency_code
where abs(coalesce(staging.spend, 0) - coalesce(fact.spend, 0)) > 0.01
   or abs(coalesce(fact.spend, 0)    - coalesce(mart.spend, 0)) > 0.01
