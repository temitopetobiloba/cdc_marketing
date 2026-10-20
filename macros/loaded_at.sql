{#
  loaded_at(relation)

  Returns the raw table's `_loaded_at` column if it has one (tables loaded by
  databricks/01_load_raw_ads.sql do), otherwise current_timestamp().

  Why: tables created through the Databricks "upload file" UI have no load
  metadata. Staging uses _loaded_at to pick the latest row when deduplicating
  and the fact uses it for incremental loads, so we need *something*.

  adapter.get_columns_in_relation asks Databricks for the table's columns at
  run time. `execute` is false while dbt only parses the project, so we skip
  the warehouse call then.
#}
{% macro loaded_at(relation) -%}
    {%- set column_names = [] -%}
    {%- if execute -%}
        {%- for col in adapter.get_columns_in_relation(relation) -%}
            {%- do column_names.append(col.name | lower) -%}
        {%- endfor -%}
    {%- endif -%}
    {%- if '_loaded_at' in column_names -%}
        cast(_loaded_at as timestamp)
    {%- else -%}
        current_timestamp()
    {%- endif -%}
{%- endmacro %}
