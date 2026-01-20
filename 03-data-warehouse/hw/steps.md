# DW Homework Steps

## Loading to GCS
- Copied a new python script from the 2025 github that works better with the nyc data source
    - Initially did a repoint to the new source, but needs a dedication download step form this source
- Setup UV and install packages needed
- Run `uv run web_to_gcs.py`

**Note:** Want to review this script more -- it does some cool stuff concurrently

## Create External Tables

```
CREATE OR REPLACE EXTERNAL TABLE `ny_taxi.external_yellow_tripdata`
OPTIONS (
  format = 'PARQUET',
  uris = ['gs://data-dino-ny-taxi/yellow_tripdata_2024-*.parquet']
);
```

## Create Regular Table (No Partition or Cluster)

```
CREATE OR REPLACE TABLE ny_taxi.yellow_tripdata_non_partitioned AS
SELECT * FROM ny_taxi.external_yellow_tripdata;
```

1. What is count of records for the 2024 Yellow Taxi Data?
    - Can look in the details of the materialized table
    - Answer: `20,332,093`

2. Write a query to count the distinct number of PULocationIDs for the entire dataset on both the tables. What is the estimated amount of data that will be read when this query is executed on the External Table and the Table.

    - Query:
        ```
        SELECT
            COUNT(DISTINCT PULocationID)
        FROM `ny_taxi.external_yellow_tripdata`;

        SELECT
            COUNT(DISTINCT PULocationID)
        FROM `ny_taxi.yellow_tripdata_non_partitioned`;
        ```
    - Answer:
        - `0MB` external
        - `155.12MB` materialized

3. Write a query to retrieve the PULocationID from the table (not the external table) in BigQuery. Now write a query to retrieve the PULocationID and DOLocationID on the same table. Why are the estimated number of Bytes different?

    - Queries:
        ```
        SELECT
            PULocationID
        FROM `ny_taxi.yellow_tripdata_non_partitioned`;

        SELECT
            PULocationID,
            DOLocationID
        FROM `ny_taxi.yellow_tripdata_non_partitioned`;
        ```
    
    - Answer: I believe this is because of the columnar storage, adding a second column increases the data scanned?

4. How many records have a fare_amount of 0?

    - Query:
        ```
        SELECT
            COUNT(*)
        FROM `ny_taxi.yellow_tripdata_non_partitioned`
        WHERE fare_amount = 0; 
        ```
    
    - Answer: `8,333`

5. What is the best strategy to make an optimized table in Big Query if your query will always filter based on tpep_dropoff_datetime and order the results by VendorID (Create a new table with this strategy)

    - Answer: should be to partition by tpep_droppoff_datetime and cluster by vendorid

    - Query:
        ```
        CREATE OR REPLACE TABLE ny_taxi.yellow_tripdata_partitioned_clustered
        PARTITION BY DATE(tpep_dropoff_datetime)
        CLUSTER BY VendorID AS
        SELECT * FROM `ny_taxi.external_yellow_tripdata`;
        ```

6. Write a query to retrieve the distinct VendorIDs between tpep_dropoff_datetime 2024-03-01 and 2024-03-15 (inclusive) Use the materialized table you created earlier in your from clause and note the estimated bytes. Now change the table in the from clause to the partitioned table you created for question 5 and note the estimated bytes processed. What are these values?

    - Queries:
        ```
        SELECT DISTINCT
            VendorID
        FROM `ny_taxi.yellow_tripdata_non_partitioned`
        WHERE DATE(tpep_dropoff_datetime) BETWEEN '2024-03-01' AND '2024-03-15';

        SELECT DISTINCT
            VendorID
        FROM `ny_taxi.yellow_tripdata_partitioned_clustered`
        WHERE DATE(tpep_dropoff_datetime) BETWEEN '2024-03-01' AND '2024-03-15';
        ```
        
    - Answer:
        - `310.24MB` non-partitioned
        - `26.84MB` partitioned

7. Where is the data stored in the External Table you created?

    - Answer: GCP Bucket

8. IT is best practice in Big Query to always cluster your data

    - Answer: False, needs to be enough data in size

9. Write a SELECT count(*) query FROM the materialized table you created. How many bytes does it estimate will be read? Why?

    - Answer: `2.72GB`, because that's the size of all the data stored in the table