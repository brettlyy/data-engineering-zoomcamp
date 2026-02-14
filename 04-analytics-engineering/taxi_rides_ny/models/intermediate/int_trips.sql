with unioned as (
    select * from {{ ref('int_trips_union') }}
),

cleaned_and_enriched as (
    select
        -- generate unique trip ID
        {{ dbt_utils.generate_surrogate_key([
            'vendor_id',
            'pickup_datetime',
            'pickup_location_id',
            'service_type'
        ]) }} as trip_id,
        vendor_id,
        service_type,
        rate_code_id,
        pickup_location_id,
        dropoff_location_id,
        pickup_datetime,
        dropoff_datetime,
        store_and_fwd_flag,
        passenger_count,
        trip_distance,
        trip_type,
        payment_type,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        ehail_fee,
        improvement_surcharge,
        total_amount
    from unioned
)

select * from cleaned_and_enriched

-- Deduplicate: if multiple trips match (same vendor, second, location, service), keep first
qualify row_number() over(
    partition by vendor_id, pickup_datetime, pickup_location_id, service_type
    order by dropoff_datetime
) = 1