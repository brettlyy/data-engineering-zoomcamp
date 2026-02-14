SELECT
    CAST(dispatching_base_num AS varchar) AS dispatching_base_num,
    CAST(pickup_datetime AS timestamp) AS pickup_datetime,
    CAST(dropOff_datetime AS timestamp) AS dropoff_datetime,
    CAST(PUlocationID AS integer) AS pickup_location_id,
    CAST(DOlocationID AS integer) AS dropoff_location_id,
    CAST(SR_Flag AS integer) AS sr_flag,
    CAST(Affiliated_base_number AS varchar) AS affiliated_base_number
FROM {{ source('raw_data', 'fhv_tripdata') }}
WHERE dispatching_base_num IS NOT NULL