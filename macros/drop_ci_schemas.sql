{#
  drop_ci_schemas(schema_prefix)

  Called by the GitHub "CI teardown" workflow when a pull request is closed.
  Drops every schema in the CI catalog that starts with the PR's schema name
  (ci_pr_12, ci_pr_12_staging, ci_pr_12_marts, ...), so CI doesn't leave
  orphan tables behind that cost storage.

  Usage:  dbt run-operation drop_ci_schemas --args '{schema_prefix: ci_pr_12}' --target ci
#}
{% macro drop_ci_schemas(schema_prefix) %}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas may only run against the ci target") }}
    {% endif %}

    {% set find_schemas %}
        show schemas in {{ target.catalog }} like '{{ schema_prefix }}*'
    {% endset %}

    {% set results = run_query(find_schemas) %}
    {% for row in results %}
        {% set schema_name = row[0] %}
        {{ log("Dropping " ~ target.catalog ~ "." ~ schema_name, info=True) }}
        {% do run_query("drop schema if exists " ~ target.catalog ~ "." ~ schema_name ~ " cascade") %}
    {% endfor %}
{% endmacro %}
