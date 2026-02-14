with trips_unioned as (
    select * from {{ ref('int_trips_union') }}
),

vendors as (
    select distinct 
        vendor_id,
        {{ get_vendor_names('vendor_id') }} AS vendor_name

    from trips_unioned
)

select * from vendors