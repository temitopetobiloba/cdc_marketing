{#
  SINGULAR TEST: a SQL query that returns the BAD rows. 0 rows returned = pass.

  Business rule: you can't click an ad you never saw, so clicks should never
  exceed impressions for an ad on a day. If it happens, the export is broken
  (columns swapped, wrong file) and the numbers shouldn't be trusted.

  Severity = warn: platforms occasionally attribute a late click to a day with
  0 impressions, so we want to SEE it rather than block production.
#}
{{ config(severity = 'warn') }}

select
    ad_performance_id,
    platform,
    date_day,
    campaign_id,
    ad_id,
    impressions,
    clicks
from {{ ref('fct_ad_performance_daily') }}
where clicks > impressions
