with green_tripdata as (
    select
        *,
        'Green' as service_type
    from {{ ref('stg_green_tripdata') }}
),

yellow_tripdata AS (
    select
        *,
        'Yellow' as service_type
    from {{ ref('stg_yellow_tripdata') }}
)

select * from green_tripdata
union all
select * from yellow_tripdata