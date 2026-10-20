{#
  clean_string(column)

  The raw exports write missing values in three different ways:
  an empty string, whitespace, or the literal text "null". This macro turns
  all three into a real SQL NULL so tests and coalesce() behave correctly.

      ' 12 ' -> '12'      'null' -> NULL      '' -> NULL

  It casts to string first, so it works whether the raw column was loaded as
  text (COPY INTO with inferSchema=false) or already typed (UI upload with
  type inference).
#}
{% macro clean_string(column) -%}
    case
        when cast({{ column }} as string) is null then null
        when trim(cast({{ column }} as string)) = '' then null
        when lower(trim(cast({{ column }} as string))) in ('null', 'none', 'nan') then null
        else trim(cast({{ column }} as string))
    end
{%- endmacro %}
