{#
  stg_snapchat__ad_stats
  GRAIN: one row per Snapchat ad, per day, per COUNTRY.
  KEY:   ad_id + date_day + country_code

  Note the finer grain than Facebook: Snapchat splits each ad-day by country.
  Renames to the shared vocabulary:
      ad_detail_id -> ad_id      ad_country -> country_code (upper-case ISO)
      swipe-ups are reported in ad_clicks and treated as clicks
  Spend is already in currency units (not micros) in this export, see
  var snapchat_spend_in_micros in dbt_project.yml.
#}

with source as (

    select * from {{ source('snapchat_ads', 'snapchat_ads_stats') }}

),

cleaned as (

    select
        {{ clean_string('ad_detail_id') }}                                  as ad_id,
        try_cast({{ clean_string('ad_date') }} as date)                     as date_day,
        upper(coalesce({{ clean_string('ad_country') }}, 'XX'))             as country_code,
        upper(coalesce({{ clean_string('ad_currency_code') }}, 'EUR'))      as currency_code,

        {% if var('snapchat_spend_in_micros') %}
        coalesce(try_cast({{ clean_string('ad_spend') }} as decimal(24, 6)) / 1000000, 0)
        {% else %}
        coalesce(try_cast({{ clean_string('ad_spend') }} as decimal(18, 6)), 0)
        {% endif %}                                                         as spend,
        coalesce(try_cast({{ clean_string('ad_impressions') }} as bigint), 0)    as impressions,
        coalesce(try_cast({{ clean_string('ad_clicks') }} as bigint), 0)         as clicks,

        {{ clean_string('ad_impressions') }} is null                        as is_impressions_missing,
        {{ clean_string('ad_clicks') }} is null                             as is_clicks_missing,

        {{ loaded_at(source('snapchat_ads', 'snapchat_ads_stats')) }} as _loaded_at

    from source

)

select *
from cleaned
where ad_id is not null
  and date_day is not null
qualify row_number() over (
    partition by ad_id, date_day, country_code
    order by _loaded_at desc
) = 1
