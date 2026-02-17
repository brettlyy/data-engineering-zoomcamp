/* @bruin

# Docs:
# - Materialization: https://getbruin.com/docs/bruin/assets/materialization
# - Quality checks (built-ins): https://getbruin.com/docs/bruin/quality/available_checks
# - Custom checks: https://getbruin.com/docs/bruin/quality/custom

# TODO: Set the asset name (recommended: staging.trips).
name: staging.trips
# TODO: Set platform type.
# Docs: https://getbruin.com/docs/bruin/assets/sql
# suggested type: duckdb.sql
type: duckdb.sql

# TODO: Declare dependencies so `bruin run ... --downstream` and lineage work.
# Examples:
# depends:
#   - ingestion.trips
#   - ingestion.payment_lookup
depends:
  - ingestion.trips
  - ingestion.payment_lookup

# TODO: Choose time-based incremental processing if the dataset is naturally time-windowed.
# - This module expects you to use `time_interval` to reprocess only the requested window.
materialization:
  # What is materialization?
  # Materialization tells Bruin how to turn your SELECT query into a persisted dataset.
  # Docs: https://getbruin.com/docs/bruin/assets/materialization
  #
  # Materialization "type":
  # - table: persisted table
  # - view: persisted view (if the platform supports it)
  type: table
  # TODO: set a materialization strategy.
  # Docs: https://getbruin.com/docs/bruin/assets/materialization
  # suggested strategy: time_interval
  #
  # Incremental strategies (what does "incremental" mean?):
  # Incremental means you update only part of the destination instead of rebuilding everything every run.
  # In Bruin, this is controlled by `strategy` plus keys like `incremental_key` and `time_granularity`.
  #
  # Common strategies you can choose FROM (see docs for full list):
  # - create+replace (full rebuild)
  # - truncate+insert (full refresh without drop/create)
  # - append (insert new rows only)
  # - delete+insert (refresh partitions based on incremental_key values)
  # - merge (upsert based on primary key)
  # - time_interval (refresh rows within a time window)
  
  #strategy: TODO
  
  # TODO: set incremental_key to your event time column (DATE or TIMESTAMP).
  
  #incremental_key: TODO_SET_INCREMENTAL_KEY
  # TODO: choose `date` vs `timestamp` based on the incremental_key type.
  
  #time_granularity: TODO_SET_GRANULARITY

# TODO: Define output columns, mark primary keys, and add a few checks.
# should include, but hiding most for simplicity
columns:
  - name: pickup_datetime
    type: timestamp
    primary_key: true
    checks:
      - name: not_null


# TODO: Add one custom check that validates a staging invariant (uniqueness, ranges, etc.)
# Docs: https://getbruin.com/docs/bruin/quality/custom
custom_checks:
  - name: row_count_greater_than_zero
    query: |
      SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
      FROM staging.trips
    value: 1

@bruin */

-- TODO: Write the staging SELECT query.
--
-- Purpose of staging:
-- - Clean and normalize schema FROM ingestion
-- - Deduplicate records (important if ingestion uses append strategy)
-- - Enrich with lookup tables (JOINs)
-- - Filter invalid rows (null PKs, negative values, etc.)
--
-- Why filter by {{ start_datetime }} / {{ end_datetime }}?
-- When using `time_interval` strategy, Bruin:
--   1. DELETES rows WHERE `incremental_key` falls within the run's time window
--   2. INSERTS the result of your query
-- Therefore, your query MUST filter to the same time window so only that subset is inserted.
-- If you don't filter, you'll insert ALL data but only delete the window's data = duplicates.

with source_data AS (
    select
        -- identifiers
        CAST(vendor_id AS integer) AS vendor_id,
        CAST(ratecode_id AS integer) AS rate_code_id,
        CAST(pu_location_id AS integer) AS pickup_location_id,
        CAST(do_location_id AS integer) AS dropoff_location_id,

        -- timestamps
        CAST(lpep_pickup_datetime AS timestamp) AS pickup_datetime,  -- lpep = Licensed Passenger Enhancement Program (green taxis)
        CAST(lpep_dropoff_datetime AS timestamp) AS dropoff_datetime,

        -- trip info
        CAST(taxi_type AS string) AS taxi_type,
        CAST(store_and_fwd_flag AS string) AS store_and_fwd_flag,
        CAST(passenger_count AS integer) AS passenger_count,
        CAST(trip_distance AS numeric) AS trip_distance,
        CAST(trip_type AS integer) AS trip_type,

        -- payment info
        CAST(fare_amount AS numeric) AS fare_amount,
        CAST(extra AS numeric) AS extra,
        CAST(mta_tax AS numeric) AS mta_tax,
        CAST(tip_amount AS numeric) AS tip_amount,
        CAST(tolls_amount AS numeric) AS tolls_amount,
        CAST(ehail_fee AS numeric) AS ehail_fee,
        CAST(improvement_surcharge AS numeric) AS improvement_surcharge,
        CAST(total_amount AS numeric) AS total_amount,
        CAST(payment_type AS integer) AS payment_type,

        -- metadata
        extracted_at
    FROM ingestion.trips
    -- Filter out records with null vendor_id (data quality requirement)
    WHERE vendor_id IS NOT NULL
),

-- Deduplicate using composite key
deduplicated AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY
        pickup_datetime,
        dropoff_datetime,
        pickup_location_id,
        dropoff_location_id,
        fare_amount
      ORDER BY extracted_at DESC
    ) AS row_num
  FROM source_data
)

SELECT
  d.pickup_datetime,
  d.dropoff_datetime,
  d.pickup_location_id,
  d.dropoff_location_id,
  d.taxi_type,
  d.passenger_count,
  d.trip_distance,
  d.payment_type,
  COALESCE(p.payment_type_name, 'unknown') AS payment_type_name,
  d.fare_amount,
  d.extra,
  d.mta_tax,
  d.tip_amount,
  d.tolls_amount,
  d.improvement_surcharge,
  d.total_amount,
  d.extracted_at
FROM deduplicated d 
LEFT JOIN ingestion.payment_lookup p ON d.payment_type = p.payment_type_id
WHERE d.row_num = 1
