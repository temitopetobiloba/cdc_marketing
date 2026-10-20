{#
  generate_schema_name — decides which SCHEMA each model lands in.

  dbt's default behaviour glues the target schema and the folder schema
  together ("dbt_tobbie_staging"). We keep that for dev and CI (so every
  developer / pull request stays isolated), but in PRODUCTION we want clean,
  stable names that analysts, BI tools and AI agents can rely on:

      target   folder schema   resulting schema
      ------   -------------   -----------------------------
      dev      staging         dbt_tobbie_staging
      ci       marts           ci_pr_12_marts
      prod     marts           marts        <- marketing_production.marts
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
