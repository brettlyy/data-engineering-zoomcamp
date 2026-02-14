{{
  config(
    materialized='incremental',
    unique_key='trip_id',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns'  )
}}

select
    t.trip_id,
    t.vendor_id,
    t.service_type,
    t.rate_code_id,

    -- Location info
    t.pickup_location_id,
    pz.borough as pickup_borough,
    pz.zone as pickup_zone,
    t.dropoff_location_id,
    dz.borough as dropoff_borough,
    dz.zone as dropoff_zone,

    -- Trip timing
    t.pickup_datetime,
    t.dropoff_datetime,
    t.store_and_fwd_flag,

    -- Trip metrics
    t.passenger_count,
    t.trip_distance,
    t.trip_type,

    -- Payment breakdown
    t.fare_amount,
    t.extra,
    t.mta_tax,
    t.tip_amount,
    t.tolls_amount,
    t.ehail_fee,
    t.improvement_surcharge,
    t.total_amount,
    t.payment_type as payment_type_code,
    pt.description as payment_type_description


from {{ ref('int_trips') }} as t
left join {{ ref('payment_type_lookup')}} pt on 
    coalesce(t.payment_type, 0) = pt.payment_type
left join {{ ref('dim_zones') }} as pz on
    t.pickup_location_id = pz.location_id
left join {{ ref('dim_zones') }} as dz on
    t.dropoff_location_id = dz.location_id

{% if is_incremental() %}
where t.pickup_datetime >= (
    select coalesce(max(pickup_datetime), '1900-01-01')
    from {{ this }}
)
{% endif %}