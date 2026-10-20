-- =============================================================================
-- 01_load_raw_ads.sql — load the 9 raw CSV files into BRONZE Delta tables.
--
-- Before running, upload each file into its own folder of the landing volume
-- (Catalog Explorer > bronze_production > marketing_raw > landing > Upload):
--
--   folder                               file
--   -----------------------------------  ---------------------------------------------------
--   landing/facebook/ads_stats/          ads_stats.csv
--   landing/facebook/ads/                new_ads_de_randomized.csv
--   landing/facebook/campaigns/          new_campaign_de_randomized.csv
--   landing/facebook/ad_groups/          new_adgroup_de_randomized.csv
--   landing/facebook/accounts/           new_acccount_de_randomized.csv
--   landing/snapchat/ads_stats/          snapchat_ads_stats.csv
--   landing/snapchat/ads/                snapchat_ads_ad_history_new_ad_names.csv
--   landing/snapchat/ad_groups/          snapchat_ads_adgroup_history_new_ad_group_names.csv
--   landing/snapchat/campaigns/          snapchat_ads_campaign_history_new_campaign_names.csv
--
-- Principles:
--   * Bronze = untouched copy. Every column lands as STRING (inferSchema false),
--     so a value like "null" in a number column never breaks the load. dbt
--     staging does the typing, and dbt tests catch the problems.
--   * Two technical columns per row: _source_file and _loaded_at.
--   * COPY INTO is IDEMPOTENT: already-loaded files are skipped, so re-running
--     this script only loads NEW files. Safe to schedule.
-- =============================================================================

use catalog bronze_production;
use schema marketing_raw;

-- ---------- Facebook ---------------------------------------------------------
create table if not exists facebook_ads_stats;
copy into facebook_ads_stats
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/facebook/ads_stats/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

create table if not exists facebook_ads;
copy into facebook_ads
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/facebook/ads/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

create table if not exists facebook_campaigns;
copy into facebook_campaigns
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/facebook/campaigns/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

create table if not exists facebook_ad_groups;
copy into facebook_ad_groups
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/facebook/ad_groups/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

create table if not exists facebook_accounts;
copy into facebook_accounts
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/facebook/accounts/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

-- ---------- Snapchat ---------------------------------------------------------
create table if not exists snapchat_ads_stats;
copy into snapchat_ads_stats
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/snapchat/ads_stats/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

create table if not exists snapchat_ads;
copy into snapchat_ads
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/snapchat/ads/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

create table if not exists snapchat_ad_groups;
copy into snapchat_ad_groups
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/snapchat/ad_groups/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

create table if not exists snapchat_campaigns;
copy into snapchat_campaigns
from (select *, _metadata.file_path as _source_file, current_timestamp() as _loaded_at
      from '/Volumes/bronze_production/marketing_raw/landing/snapchat/campaigns/')
fileformat = csv
format_options ('header' = 'true', 'inferSchema' = 'false')
copy_options ('mergeSchema' = 'true');

-- ---------- Check: expected row counts --------------------------------------
-- facebook_ads_stats 92,300 · facebook_ads 98,926 · facebook_campaigns 4,162
-- facebook_ad_groups 13,433 · facebook_accounts 16
-- snapchat_ads_stats 2,809 · snapchat_ads 2,513 · snapchat_ad_groups 267 · snapchat_campaigns 109
select 'facebook_ads_stats' as table_name, count(*) as row_count from facebook_ads_stats
union all select 'facebook_ads',        count(*) from facebook_ads
union all select 'facebook_campaigns',  count(*) from facebook_campaigns
union all select 'facebook_ad_groups',  count(*) from facebook_ad_groups
union all select 'facebook_accounts',   count(*) from facebook_accounts
union all select 'snapchat_ads_stats',  count(*) from snapchat_ads_stats
union all select 'snapchat_ads',        count(*) from snapchat_ads
union all select 'snapchat_ad_groups',  count(*) from snapchat_ad_groups
union all select 'snapchat_campaigns',  count(*) from snapchat_campaigns;
