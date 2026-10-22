# Initialize Project  
uv init --bare --name cdc_marketing --python 3.12

# add databricks to the project 
uv add dbt-databricks

# Initialize dbt project - this creates the dbt setup
uv run dbt init cdc_marketing --skip-profile-setup

#Initialize dbt profile - this creates the profile.yml file
touch profiles.yml

#Update the profiles.yml file with matching details for your databricks account. You can find these details in your databricks account under SQL Warehouses.
uv run dbt debug to confirm that the dbt profile is working correctly with your databricks account.

# Update the .env file with your databricks account details. You can find these details in your databricks account under SQL Warehouses.

# uv run dbt deps                          # if not done yet
uv run dbt seed                          # exchange-rate table
uv run dbt build --select staging        # 9 views + their tests
uv run dbt build                         # intermediate + marts + all tests