-- =============================================================================
-- 00_setup_catalogs.sql — run ONCE in the Databricks SQL editor as an admin.
--
-- Unity Catalog address = catalog.schema.table  (3 levels)
--
--   catalog                purpose                              who writes
--   ---------------------  -----------------------------------  ----------------
--   bronze_production      raw files, loaded unchanged           loader / SP
--   third_layer            development dbt sandbox (exists)      developers
--   ci_development         one throwaway schema per pull request CI
--   marketing_production   production dbt models (what users read) Service Principal
--
-- Separate CATALOGS (not just schemas) per environment give a hard security
-- boundary: CI and dev can't accidentally touch production tables.
-- =============================================================================

create catalog if not exists bronze_production;
create catalog if not exists ci_development;
create catalog if not exists marketing_production;

create schema if not exists bronze_production.marketing_raw
  comment 'Raw advertising exports (Facebook, Snapchat). Loaded as-is, all STRING.';

-- A Volume is a governed folder for files. Upload the CSVs here:
--   Catalog Explorer > bronze_production > marketing_raw > landing > Upload
--   one folder per table, e.g. landing/facebook/ads_stats/ads_stats.csv
--   (full mapping at the top of 01_load_raw_ads.sql)
create volume if not exists bronze_production.marketing_raw.landing
  comment 'Landing zone for raw ad-platform export files.';
