{#
  safe_divide(numerator, denominator)

  Returns NULL instead of crashing (or returning infinity) when the denominator
  is 0 or NULL. Used for CTR, CPC and CPM.

  Why NULL and not 0?  A campaign with 0 clicks does NOT have a CPC of 0 —
  that would make it look like the cheapest campaign. "Undefined" is the honest
  answer, and BI tools / AI agents skip NULLs when averaging.
#}
{% macro safe_divide(numerator, denominator) -%}
    case
        when {{ denominator }} is null or {{ denominator }} = 0 then null
        else cast({{ numerator }} as decimal(18, 6)) / {{ denominator }}
    end
{%- endmacro %}
