-- =============================================================================
-- 02_unity_catalog_grants.sql — who may do what (principle of LEAST PRIVILEGE)
--
-- Replace the two placeholders before running:
--   <SERVICE_PRINCIPAL_APP_ID>  Settings > Identity and access > Service principals
--                               > your SP > "Application ID" (a UUID)
--   temitopetobiloba@gmail.com  your own user (used for dev + CI)
--
-- Unity Catalog permissions are hierarchical: to read a table you need
--   USE CATALOG on the catalog  +  USE SCHEMA on the schema  +  SELECT on the table.
-- Granting at catalog level cascades to everything inside it.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1. PRODUCTION SERVICE PRINCIPAL (used by the GitHub deploy workflow)
-- ---------------------------------------------------------------------------

-- Read the raw tables (third_layer.marketing_staging); dbt never writes there
grant use catalog on catalog third_layer                      to `<SERVICE_PRINCIPAL_APP_ID>`;
grant use schema  on schema  third_layer.marketing_staging  to `<SERVICE_PRINCIPAL_APP_ID>`;
grant select      on schema  third_layer.marketing_staging  to `<SERVICE_PRINCIPAL_APP_ID>`;
-- (Optional) if the SP also runs 01_load_raw_ads.sql as a Databricks Job:
-- grant modify, create table on schema third_layer.marketing_staging to `<SERVICE_PRINCIPAL_APP_ID>`;
-- grant read volume on volume third_layer.marketing_staging.landing  to `<SERVICE_PRINCIPAL_APP_ID>`;

-- Build the production models: create schemas (staging, marts, elementary...) and tables
grant use catalog   on catalog marketing_production to `<SERVICE_PRINCIPAL_APP_ID>`;
grant use schema    on catalog marketing_production to `<SERVICE_PRINCIPAL_APP_ID>`;
grant create schema on catalog marketing_production to `<SERVICE_PRINCIPAL_APP_ID>`;
grant create table  on catalog marketing_production to `<SERVICE_PRINCIPAL_APP_ID>`;
grant select        on catalog marketing_production to `<SERVICE_PRINCIPAL_APP_ID>`;
grant modify        on catalog marketing_production to `<SERVICE_PRINCIPAL_APP_ID>`;

-- The SP also needs permission to use the SQL warehouse:
--   SQL Warehouses > <warehouse> > Permissions > add SP with "Can use"


-- ---------------------------------------------------------------------------
-- 2. DEVELOPER / CI USER (personal identity, never touches production writes)
-- ---------------------------------------------------------------------------

-- Read raw data so dev and CI builds have something to transform
grant use catalog on catalog third_layer                     to `temitopetobiloba@gmail.com`;
grant use schema  on schema  third_layer.marketing_staging to `temitopetobiloba@gmail.com`;
grant select      on schema  third_layer.marketing_staging to `temitopetobiloba@gmail.com`;

-- Full sandbox rights in development and CI catalogs
grant use catalog, use schema, create schema, create table, select, modify
  on catalog third_layer to `temitopetobiloba@gmail.com`;      -- dev catalog
grant use catalog, use schema, create schema, create table, select, modify
  on catalog ci_development  to `temitopetobiloba@gmail.com`;

-- Read-only on production (look, don't touch)
grant use catalog, use schema, select
  on catalog marketing_production to `temitopetobiloba@gmail.com`;


-- ---------------------------------------------------------------------------
-- 3. CONSUMERS: analysts, BI tool, AI agents read ONLY the marts schema
-- ---------------------------------------------------------------------------
-- Create a group "marketing_analysts" under Settings > Identity and access > Groups
-- grant use catalog on catalog marketing_production       to `marketing_analysts`;
-- grant use schema  on schema  marketing_production.marts to `marketing_analysts`;
-- grant select      on schema  marketing_production.marts to `marketing_analysts`;


-- ---------------------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------------------
show grants on catalog marketing_production;
show grants on schema  third_layer.marketing_staging;
