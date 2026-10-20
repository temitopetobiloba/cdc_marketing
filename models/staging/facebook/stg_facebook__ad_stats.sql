{#
  stg_facebook__ad_stats
  GRAIN: one row per Facebook ad per day.   KEY: ad_id + date_day

  * casts text to DATE / DECIMAL / BIGINT
  * the literal text "null" -> NULL (clean_string macro)
  * NULL clicks/impressions -> 0, with a flag. Evidence from the data:
    24k rows have "null" clicks but only 42 have an explicit 0, and the "null"
    rows are tiny (median 24 impressions vs 2,661). Facebook omits a metric
    when it is zero, so "null" means "none recorded", not "unknown".
  * deduplicates in case the same file is loaded twice (keeps the latest load)
#}

with source as (

    select * from {{ source('facebook_ads', 'facebook_ads_stats') }}

),

cleaned as (

    select
        {{ clean_string('ad_id') }}                                         as ad_id,
        {{ clean_string('account_id') }}                                    as account_id,
        try_cast({{ clean_string('ad_date') }} as date)                     as date_day,

        coalesce(try_cast({{ clean_string('ad_spend') }} as decimal(18, 6)), 0)  as spend,
        coalesce(try_cast({{ clean_string('ad_impressions') }} as bigint), 0)    as impressions,
        coalesce(try_cast({{ clean_string('ad_clicks') }} as bigint), 0)         as clicks,

        {{ clean_string('ad_impressions') }} is null                        as is_impressions_missing,
        {{ clean_string('ad_clicks') }} is null                             as is_clicks_missing,

        {{ loaded_at(source('facebook_ads', 'facebook_ads_stats')) }} as _loaded_at

    from source

)

select *
from cleaned
where ad_id is not null
  and date_day is not null
qualify row_number() over (partition by ad_id, date_day order by _loaded_at desc) = 1
