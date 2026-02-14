# Steps and Notes for Homework 4

## Build Notes
- All models are setup in the [models directory](./../models/).
- Ran out of memory at 2GB and 4GB settings, only have 8GB of RAM

also updated [project yaml](./../../dbt_project.yml) with this to save some space hopefully.
```
models:
  taxi_rides_ny:
    staging:
      +materialized: ephemeral
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
```

And updated [staging sources](./../models/staging/sources.yml) to try to pull from the parquet files rather than having to load them raw.

## Homework questions

1. If you run `dbt run --select int_trips_unioned` what models will be built when you have that in an intermediate directory, but it relies on upstream models in staging?

- Answer: `int_trips_unioned only`

- Note: I didn't materialized my staging and int views to save space, so couldn't verify this.

2. Have a generic test in `schema.yml`:

```
columns:
  - name: payment_type
    data_tests:
      - accepted_values:
          arguments:
            values: [1, 2, 3, 4, 5]
```

A new value - 6 - appears in source data. What happens when you run `dbt test --select fct_trips`?

- Answer: `Fail the test, returning non-zero exit code.`

- Note: tried adding in only 1 as an accepted value to see what would happen if I ran dbt test --select fct_trips.

3. What is the count of records in the monthly revenue model?

- SQL:
    ```sql
    SELECT
        COUNT(*)
    FROM ny_taxi.prod.fct_location_monthly_revenue
    ```

- Answer: `12,184`

4. What pickup zone had the highest total revenue for green taxi trips in 2020?

- SQL:
    ```sql
    select
        pickup_zone
    from ny_taxi.prod.fct_location_monthly_revenue
    where year(revenue_month) = 2020
        and service_type = 'Green'
    order by revenue_monthly_total_amount desc
    limit 1;
    ```

- Answer: `East Harlem North`

5. What is the total number of trips for green taxis in October 2019?

- SQL:
    ```sql
    select
        sum(total_monthly_trips)
    from ny_taxi.prod.fct_location_monthly_revenue
    where revenue_month = date'2019-10-01'
        and service_type = 'Green'
  ```

- Answer: `384,624`

6. Create a staging model for For-Hire vehicle 2019 data.
- filter out dispatching_base_num IS NULL
- rename fields

What is the count of records in `stg_fhv_tripdata`?

- Steps:
    - Download 2019 data and save to [data folder](./../data/fhv/)
    - Add that path as an external source (skipped warehouse load)
    - cte model with minor transforms/filters then record count

- Answer: `43,244,693`

