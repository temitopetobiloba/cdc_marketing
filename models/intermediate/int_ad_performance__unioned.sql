{#
  int_ad_performance__unioned
  GRAIN: one row per platform, ad, day and country.

  1. Stacks every platform into one dataset. Adding TikTok later = one more
     int_tiktok__ad_performance model + one name in the list below.
  2. Converts spend to EUR with the rate valid on the reporting day, so
     Facebook's USD accounts and EUR accounts can be added up correctly.
  3. Builds the row's primary key.

  EPHEMERAL: inlined as a CTE into the fact table. It has no consumers of
  its own, so no view/table is created for it in the catalog.
#}

{{ config(materialized = 'ephemeral') }}

{% set platform_models = ['int_facebook__ad_performance', 'int_snapchat__ad_performance'] %}

with unioned as (

    {% for model_name in platform_models %}
    select * from {{ ref(model_name) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

),

rates as (

    select * from {{ ref('currency_rates') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['unioned.platform', 'unioned.ad_id', 'unioned.date_day', 'unioned.country_code']) }}
                                                    as ad_performance_id,
    unioned.*,
    rates.rate_to_eur,
    cast(unioned.spend * rates.rate_to_eur as decimal(18, 6)) as spend_eur
from unioned
left join rates
    on  unioned.currency_code = rates.currency_code
    and unioned.date_day between rates.valid_from and rates.valid_to
