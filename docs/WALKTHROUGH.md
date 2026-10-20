# End-to-end walkthrough: how this project works, step by step

This guide follows the data from a CSV file to an answer on a dashboard. Each
step has three parts: **the idea**, **what you do**, and **what to check**.
Commands use `uv run`, because that's how you installed dbt.

---

## Step 0: The big picture

> Raw files go into Databricks untouched (**bronze**). dbt cleans and reshapes them in layers
> (**staging → intermediate → marts**), with tests guarding every layer. GitHub Actions runs it
> all automatically in separate environments (**dev, CI, prod**).

Each layer has **one job**, so when something breaks you know where to look:
wrong column name → staging; wrong join → intermediate; wrong total → marts.

---

## Step 1: Put the project in your folder

Your folder `marketing-data-platform/cdc_marketing` already has a working connection.
1. **Before overwriting anything**, open your current `profiles.yml` and copy the `host`,
   `http_path` and `token` values into a new file `.env` (template: `.env.example`).
2. Copy this project's files into your folder (replace `dbt_project.yml`, `profiles.yml`, `README.md`; keep `pyproject.toml` / `uv.lock`).
3. Load the variables and check the connection:
   ```bash
   set -a; source .env; set +a
   uv add "elementary-data[databricks]"
   uv run dbt deps
   uv run dbt debug        # "All checks passed!"
   ```

**Why env vars?** The new `profiles.yml` contains no secrets, so it can go into Git.
It defines three targets (`dev`, `ci`, `prod`). Your dev target still points at catalog `third_layer`.

---

## Step 2: Unity Catalog and raw data (bronze)

**Idea.** Databricks addresses tables as `catalog.schema.table`. Raw files are copied
**unchanged** into bronze, with every column as text, so a value like `"null"` never breaks
the load. A *volume* is a governed folder for files; `COPY INTO` loads them and remembers which files
it already loaded (safe to re-run).

**Do.**
1. Run `databricks/00_setup_catalogs.sql` in the SQL editor.
2. Upload each CSV into its own folder under `landing/` (mapping table at the top of `01_load_raw_ads.sql`).
   You don't need the Snapchat zip; it contains the same four files.
3. Run `databricks/01_load_raw_ads.sql`.

**Check.** The final query's row counts match the expected numbers in the script
(e.g. `facebook_ads_stats` 92,300, `snapchat_ads_stats` 2,809).

> **Already loaded your files another way?** (You did: `third_layer.marketing_staging.facebook_1` …
> `snapchat_4`.) Then skip this step. The sources already point there, and each source table has an
> `identifier:` naming the real table. Run the "Which raw table is which?" query in README §5.1
> and fix any `identifier:` that doesn't match.
>
> **Why the models build into `marketing_dev_*` and not `marketing_staging`:** raw data and
> transformed data should never share a schema. Otherwise nobody can tell the untouched copy from
> the cleaned one, and a `dbt` run could overwrite a raw table with the same name.

---

## Step 3: Sources, telling dbt where raw data is

**Idea.** A *source* is a table dbt reads but didn't build. Models write
`{{ source('facebook_ads', 'facebook_ads_stats') }}` instead of a hard-coded name, so dbt can
draw lineage and check freshness.

**Read.** `models/staging/facebook/_facebook__sources.yml`: it also documents each platform's hierarchy.

**Do.** `uv run dbt source freshness`

---

## Step 4: Seeds, reference data from Git

**Idea.** Facebook accounts bill in **EUR and USD**. Adding them up raw would mix currencies.
`seeds/currency_rates.csv` is a small table you maintain in Git; `dbt seed` loads it.

**Do.** `uv run dbt seed`, then query `third_layer.marketing_reference.currency_rates`.

---

## Step 5: Staging, one model per source table

**Idea.** Staging is the *only* place that knows each file's quirks. Each model:
* renames to our vocabulary (`ad_detail_id` → `ad_id`, `ad_country` → `country_code`)
* casts types with `try_cast` (bad value → NULL instead of a crash)
* turns `"null"`, `""` and whitespace into real NULLs (macro `clean_string`)
* sets missing clicks/impressions to 0 **and keeps a flag** (`is_clicks_missing`)
* deduplicates with `qualify row_number() over (...) = 1`, e.g. Snapchat's ad group history keeps the latest version

**Do.**
```bash
uv run dbt build --select staging
```
**Check.** `select * from third_layer.marketing_staging.stg_snapchat__ad_stats limit 10`

Look at the test output: the Snapchat ad → ad group relationship test **warns** (12% of
ads have no ad group in the export). It's a warning because none of them has spend.

---

## Step 6: Intermediate, joining each platform, then stacking

**Idea.** The stats tables only contain IDs and numbers. Each platform gets one model that
joins its hierarchy and outputs the **same columns**:

```
Facebook:  stats → ads → (ad sets, campaigns) ; stats → accounts (currency)
Snapchat:  stats → ads → ad groups → campaigns (account)
```

Then `int_ad_performance__unioned` stacks them with `UNION ALL` and converts spend to EUR
using the rate valid on that day. It is **ephemeral**: no table is created, and its SQL is pasted into
the fact table as a CTE.

**Do.**
```bash
uv run dbt build --select intermediate
uv run dbt compile --select fct_ad_performance_daily
```
Open `target/compiled/cdc_marketing/models/marts/marketing/fct_ad_performance_daily.sql`.
You'll see the union inlined; that's what *ephemeral* means.

---

## Step 7: Marts, the business-ready tables

**Grain first.** Write down what one row means before writing SQL:

| Model | One row = | Type |
|---|---|---|
| `fct_ad_performance_daily` | ad × platform × day × country | **fact**: numbers you can sum |
| `dim_campaigns` | campaign × platform | **dimension**: descriptions |
| `mart_campaign_performance_daily` | campaign × platform × day | **wide table** for consumers |

**Additive vs non-additive.** Spend, impressions and clicks can be summed. CTR, CPC and CPM
**cannot**: the average of two CPCs is not the CPC of both together. Always sum, then divide.

**Incremental.** The first run builds everything. Later runs only process recent days and
**merge** them (update existing rows, insert new ones).

**Do.**
```bash
uv run dbt build                                       # everything, in order, with tests
uv run dbt build --select fct_ad_performance_daily     # again: log says "incremental"
uv run dbt build --full-refresh                        # rebuild from scratch
```
**Check.** Run `analyses/business_questions.sql`. Expected: Facebook ≈ €8.64M, Snapchat ≈ €30.5k.

---

## Step 8: Tests

**Idea.** A test is a query that returns the **bad rows**: zero rows = pass.
* **Generic** (YAML): `unique`, `not_null`, `accepted_values`, `relationships`
* **Package**: `dbt_utils.expression_is_true`, `unique_combination_of_columns`, `accepted_range`
* **Singular** (`tests/*.sql`): clicks ≤ impressions; **spend reconciles staging → fact → mart**

`severity: warn` reports without stopping. Errors stop `dbt build` from building anything downstream.

**Try it.** In `int_snapchat__ad_performance.sql` change `'snapchat' as platform` to
`'Snapchat' as platform`, run
`uv run dbt build`, read the `accepted_values` failure, then undo it.

---

## Step 9: Documentation and lineage

```bash
uv run dbt docs generate
uv run dbt docs serve               # http://localhost:8080 → lineage button bottom-right
uv run dbt docs generate --static   # one file: target/static_index.html (deliverable)
```

---

## Step 10: Elementary

**Idea.** dbt says whether *this* run passed. Elementary stores **every** run's results, so you can
see history and spot anomalies (volume, spend).

```bash
uv run dbt run --select elementary        # first time: creates its tables
uv run dbt build                          # results upload automatically
uv run edr report --profile-target dev    # HTML report
```
The `elementary` profile in `profiles.yml` tells `edr` where those tables are.

---

## Step 11: Service Principal (production identity)

1. Databricks → Settings → Identity and access → Service principals → **Add**.
2. Open it → **Secrets** → Generate. Copy client ID + secret (shown once).
3. SQL Warehouses → your warehouse → Permissions → SP gets **Can use**.
4. Put the Application ID into `databricks/02_unity_catalog_grants.sql`, run it.
5. Optional local test:
   ```bash
   export DATABRICKS_CLIENT_ID=... DATABRICKS_CLIENT_SECRET=...
   uv run dbt debug --target prod
   ```

---

## Step 12: Git and CI/CD

```
git checkout -b feature/x → change → uv run dbt build → git push → Pull Request
  → ci.yml builds + tests in ci_pr_<N> → green ✓ + review → merge
  → deploy_prod.yml runs as the Service Principal → docs to GitHub Pages
PR closed → ci_teardown.yml drops the CI schemas
```
Setup: GitHub → Settings → Environments `ci` + `production` (secrets in README §5.3),
Branches → protect `main` with the **dbt-ci** check, Pages → GitHub Actions.

---

## Cheat sheet

| Command | What it does |
|---|---|
| `uv run dbt deps` | install packages |
| `uv run dbt debug` | test connection |
| `uv run dbt seed` | load CSV seeds |
| `uv run dbt build` | seeds + models + tests, in order (use this) |
| `uv run dbt build -s +mart_campaign_performance_daily` | a model and everything upstream |
| `uv run dbt build -s staging` | one folder |
| `uv run dbt build --full-refresh` | rebuild incremental models |
| `uv run dbt compile` | see final SQL without running it |
| `uv run dbt docs generate --static` | single-file HTML docs |
| `uv run edr report` | Elementary report |

## Common errors

| Error | Usual cause |
|---|---|
| `Could not find profile named 'cdc_marketing_profile'` | Running from another folder, or profiles.yml not copied |
| `Env var required but not provided: 'DATABRICKS_HOST'` | Forgot `set -a; source .env; set +a` in this terminal |
| `TABLE_OR_VIEW_NOT_FOUND ... facebook_ads_stats` | Raw tables not loaded, or `DBT_RAW_CATALOG/SCHEMA` point elsewhere |
| `PERMISSION_DENIED ... USE CATALOG` | Missing grant: re-run the grants script |
| `'dbt_utils' is undefined` | Forgot `uv run dbt deps` |
| `unique` test fails on a key | Duplicates in raw or a wrong grain: check the `qualify` partition |
