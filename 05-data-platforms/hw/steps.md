# Module 5 Howeork

- Ran through the bruin tutorial [here](https://github.com/bruin-data/bruin/tree/main/templates/zoomcamp#part-5-deploy-to-cloud)

- Setup project pulling green taxi data since it's smaller than the yellow.

## Questions

1. In a Bruin project, what are the required files/directories?

- Answer: Need a .bruin.yml somewhere. Also need assets and pipeline.yml. So think the best answer is .bruin.yml and pipeline/ with pipeline.yml and assets/.

2. You're building a pipeline that processes NYC taxi data organized by month based on pickup_datetime. Which materialization strategy should you use for the staging layer that deduplicates and cleans the data?

- Answer: With the consistent time-based field I think the best answer is `time_interval` that way you can incrementally load.

3. You have the following variable defined in pipeline.yml:
    ```yaml
    variables:
    taxi_types:
        type: array
        items:
        type: string
        default: ["yellow", "green"]
    ```
How do you override this when running the pipeline to only process yellow taxis?

- Answer: `bruin run --set taxi_types=["yellow"]`

4. You've modified the ingestion/trips.py asset and want to run it plus all downstream assets. Which command should you use?

- Answer: `bruin run ingestion/trips.py --downstream`

5. You want to ensure the pickup_datetime column in your trips table never has NULL values. Which quality check should you add to your asset definition?

- Answer: `not_null: true`

6. After building your pipeline, you want to visualize the dependency graph between assets. Which Bruin command should you use?

- Answer: `bruin lineage`

7. You're running a Bruin pipeline for the first time on a new DuckDB database. What flag should you use to ensure tables are created from scratch?

- Answer: `--full-refresh`