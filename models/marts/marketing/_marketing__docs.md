{% docs metric_spend %}
**Spend (EUR)**: money paid to the advertising platform, converted to euros
with the rate valid on the reporting day (seed `currency_rates`). Facebook
accounts bill in EUR or USD; Snapchat in EUR. Additive: safe to `SUM` across
days, campaigns, accounts and platforms.
{% enddocs %}

{% docs metric_impressions %}
**Impressions**: number of times an ad was displayed on screen. Additive.
{% enddocs %}

{% docs metric_clicks %}
**Clicks**: clicks on Facebook, swipe-ups on Snapchat, harmonised as one
"click" concept. Source values of "null" are stored as 0 (flagged). Additive.
{% enddocs %}

{% docs metric_ctr %}
**CTR (click-through rate)** = clicks ÷ impressions. Share of impressions that
led to a click (0.012 = 1.2 %). NULL when impressions = 0.
⚠ Not additive: when aggregating, use `sum(clicks) / sum(impressions)`, never `avg(ctr)`.
{% enddocs %}

{% docs metric_cpc %}
**CPC (cost per click, EUR)** = spend_eur ÷ clicks. NULL when clicks = 0 (cost per
click is undefined, not zero).
⚠ Not additive: when aggregating, use `sum(spend_eur) / sum(clicks)`.
{% enddocs %}

{% docs metric_cpm %}
**CPM (cost per mille, EUR)** = spend_eur ÷ impressions × 1,000: the cost of 1,000
impressions. NULL when impressions = 0.
⚠ Not additive: when aggregating, use `sum(spend_eur) * 1000 / sum(impressions)`.
{% enddocs %}

{% docs platform %}
Advertising platform the row comes from. Always lower-case: `facebook` or `snapchat`.
{% enddocs %}

{% docs __overview__ %}
# Marketing Data Platform

Unified, tested and documented advertising performance for **Facebook Ads** and
**Snapchat Ads**.

**Start here:** `mart_campaign_performance_daily`: one row per campaign per
platform per day, with spend (EUR), impressions, clicks, CTR, CPC and CPM.

| Layer | Models | Materialization |
|---|---|---|
| Sources (bronze) | 5 Facebook + 4 Snapchat raw tables | Delta, loaded by COPY INTO |
| Seed | `currency_rates` | table (from CSV in Git) |
| Staging | one `stg_<platform>__<table>` per source table | view |
| Intermediate | `int_facebook__ad_performance`, `int_snapchat__ad_performance` | view |
| | `int_ad_performance__unioned` (+ EUR conversion) | ephemeral |
| Marts | `fct_ad_performance_daily` | incremental (merge) |
| | `dim_campaigns`, `mart_campaign_performance_daily` | table |

**Data coverage:** Facebook 2025-01-01 → 2025-12-31 · Snapchat 2024-01-01 → 2024-12-02
(no Snapchat data for April, May and October 2024).

Open the **lineage graph** (bottom-right button) to see how data flows.
{% enddocs %}
