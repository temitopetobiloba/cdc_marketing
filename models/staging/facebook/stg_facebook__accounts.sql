{#
  stg_facebook__accounts
  GRAIN: one row per Facebook ad account.   KEY: account_id
  Important because it carries the CURRENCY of the account's spend:
  some accounts bill in USD, others in EUR.
#}

with source as (

    select * from {{ source('facebook_ads', 'facebook_accounts') }}

)

select
    {{ clean_string('account_id') }}                                    as account_id,
    {{ clean_string('account_name') }}                                  as account_name,
    upper({{ clean_string('ad_currency_code') }})                       as currency_code,
    try_cast({{ clean_string('account_created_at') }} as timestamp)     as account_created_at,
    try_cast({{ clean_string('account_updated_at') }} as timestamp)     as account_updated_at,
    {{ loaded_at(source('facebook_ads', 'facebook_accounts')) }} as _loaded_at
from source
where {{ clean_string('account_id') }} is not null
qualify row_number() over (
    partition by {{ clean_string('account_id') }}
    order by try_cast({{ clean_string('account_updated_at') }} as timestamp) desc
) = 1
