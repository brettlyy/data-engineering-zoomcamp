# BigQuery & Data Warehouses

## OLAP VS OLTP

![alt text](<Screenshot 2026-01-18 at 10.12.33 AM.png>)

![alt text](<Screenshot 2026-01-18 at 10.13.22 AM.png>)

## Data Warehouses

- OLAP solution for reporting and analysis
- Masny data sources pushed to staging and then warehouses
- Can push to data marts for different subject matters or look at raw data

## BigQuery Intro
GCPs data warehouse
- Serverless
- Stores data separately from compute engine

- Can toggle caching of data

### BQ Cost
- On demand: $5 per TB data processed
- Flat rate: based on pre-requested slots
    - 100 slots -> $2k/month = 400 TB of on-demand
    - Not worth it below 200TB
    - Also introduces concurrency limits

### Setting up Tables

- Can create external table in SQL -> point to GCS location with CSV in options
    ```
    -- Creating external table referring to gcs path
    CREATE OR REPLACE EXTERNAL TABLE `taxi-rides-ny.nytaxi.external_yellow_tripdata`
    OPTIONS (
    format = 'CSV',
    uris = ['gs://nyc-tl-data/trip data/yellow_tripdata_2019-*.csv', 'gs://nyc-tl-data/trip data/yellow_tripdata_2020-*.csv']
    );
    ```
    - external tables won't map size or estimated scan in metadata or when querying

- Create table in BQ storage
    ```
    -- Create a non partitioned table from external table
    CREATE OR REPLACE TABLE taxi-rides-ny.nytaxi.yellow_tripdata_non_partitioned AS
    SELECT * FROM taxi-rides-ny.nytaxi.external_yellow_tripdata;
    ```

### Partitioning
- Use to limit scans, speed up queries and reduce cost
    ![alt text](<Screenshot 2026-01-18 at 10.20.22 AM.png>)
    ```
    -- Create a partitioned table from external table
    CREATE OR REPLACE TABLE taxi-rides-ny.nytaxi.yellow_tripdata_partitioned
    PARTITION BY
    DATE(tpep_pickup_datetime) AS
    SELECT * FROM taxi-rides-ny.nytaxi.external_yellow_tripdata;
    ```

- Can review partitions, table, partition_id and total rows to look for hot partitions
    ```
    SELECT table_name, partition_id, total_rows
    FROM `nytaxi.INFORMATION_SCHEMA.PARTITIONS`
    WHERE table_name = 'yellow_tripdata_partitioned'
    ORDER BY total_rows DESC;
    ```

- Partition limit is 4000
    - Can have expiring partition strategy do use a lot of partitions
- Can use time unit or integer range

### Clustering
- Additional breakouts for partitions, like using categories/tags, for additional cost and time savings
    ![alt text](<Screenshot 2026-01-18 at 10.24.04 AM.png>)

    ```
    -- Creating a partition and cluster table
    CREATE OR REPLACE TABLE taxi-rides-ny.nytaxi.yellow_tripdata_partitioned_clustered
    PARTITION BY DATE(tpep_pickup_datetime)
    CLUSTER BY VendorID AS
    SELECT * FROM taxi-rides-ny.nytaxi.external_yellow_tripdata;
    ```

- Cluster selections depends on how you want to query the data most often.
- Note: estimation won't necessarily pickup these savings, will see in actual results
- Improves filter and aggregate queries
- Order of column  matters - specifies the sort order of the data
- Can have up to 4 clustering columns

#### Auto-Reclustering

BQ does auto-reclustering in background to keep the sort property of the table clean since new data can be written to overlapping blocks

- If using parittioning too, each parition is clustered independently

**Note:** Partitioning and clustering not really useful for tables <1GB

### Partition vs. Clustering

![alt text](<Screenshot 2026-01-18 at 10.31.28 AM.png>)

#### Clustering over partitioning

- small amount of data per partition
- partitions beyond limit of partitions
- partitioning results in a lot of modifications to the partitions frequently

## BigQuery Best Practices

- Cost Reduction
    - avoid select *
    - use clustering and partitioning when tables large enough
    - use streaming inserts with caution
    - materialize query results in stages

- Query Performance
    - filter on partitions
    - denormalize data
    - use nested or repeated columns
    - reduce data before joining
    - use external data sources appropriately
    - avoid oversharding
    - avoid JS UDFs
    - place tables in descending order of rows
    - order last 

## BigQuery Internals
![alt text](<Screenshot 2026-01-19 at 9.50.10 AM.png>)

- Separate storage and compute
- Storage in "colossus" in columnar format
- Jupiter server gives fast compute
- Dremel layer performs query execution distributing between nodes

## BigQuery Machine Learning
Perform training and running of ML model all within BQ

### Pricing
- Free: 10GB storage, 1TB queries, 10GB create model per month
- Then $250 per TB or $5 depending on operation. Most common are $250/TV (regression)

### ML Example
See [SQL resource](./../03-data-warehouse/big_query_ml.sql)

- Some auto transformations, like numerical value standardization and one-hot endcoding
    - Note: so we convert Location IDs to string so it doesn't treat as a numerical important variable
- Also manual preprocessing functions
- Can do hyperparameter tuning as well

[Create Model Reference](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-create)

### BQ ML Deployment
See [reference](./../03-data-warehouse/extract_model.md)

- Export model to GCS using gcloud cli
- use `gsutil cp` to copy model to local temp file
- run tensorflow on docker
- Can access tensorflow endpoint via API call on your localhost