# Steps Taken for Homework

1. Run `python:3.13` image with `bash` entrypoint. What is the version of pip?
    - Run image with:
        ```
        docker run -it \
            --rm \
            --entrypoint=bash \
            python:3.13
        ```
    - Run `pip -V`
    - Answer:
        ```
        root@c0d1ba7e4774:/# pip -V
        pip 25.3 from /usr/local/lib/python3.13/site-packages/pip (python 3.13)
        ```

2. What hostname and port should pgAdmin connect to?
    - Relavant info:
        - db container name = `postgres`
        - db ports is `5433:5432`

    - I think this means that if connecting from my local device, use 5433.
    - But in the network with pgadmin connect with 5432 because no port mapping is needed

    - Run `docker-compose up`
    - Connect to the database in pgadmin
        - Worked with both `postgres:5432` and `db:5432`
        - According to AI, both work but db is more stable while the container name can change


## Insert Data into Postgres

- Keep docker compose setup
- Setup a python ingestion script: [script](./ingest_data.py)
- Setup Dockefile to push the script to a container: `docker build -t green_ingest:v001 .`
    ```
    FROM python:3.13.11-slim
    COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin

    WORKDIR /code
    ENV PATH="/code/.venv/bin:$PATH"

    COPY pyproject.toml .python-version uv.lock ./
    RUN uv sync --locked

    COPY ingest_data.py .

    ENTRYPOINT ["python", "ingest_data.py"]
    ```

- Run the container on the network
    ```
    docker run -it --rm \
        --network=hw_default \
        green_ingest:v001
    ```

**Note:** Keep using uv for managing packages

## SQL Questions

3. In November 2025, how many trips where less than or equal to a mile?

    ```
    SELECT
        COUNT(*)
    FROM public.green_taxi_trips
    WHERE lpep_pickup_datetime >= '2025-11-01'
        AND lpep_pickup_datetime < '2025-12-01'
        AND trip_distance <= 1.0;
    ```

    - Answer: 8,007

4. What day had the longest trip distance?

    ```
    SELECT
        DATE(lpep_pickup_datetime),
        MAX(trip_distance)
    FROM public.green_taxi_trips
    WHERE trip_distance < 100.0
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 1;
    ```

    - Answer: 2025-11-14

5. Biggest Pickup Zone

    ```
    SELECT
        zones."Zone",
        SUM(trips.total_amount)
    FROM public.green_taxi_trips AS trips
    LEFT JOIN public.zones_lookup AS zones ON trips."PULocationID" = zones."LocationID"
    WHERE DATE(trips.lpep_pickup_datetime) = '2025-11-18'
    GROUP BY 1
    ORDER BY 2 DESC;
    ```

    - Answer: East Harlem North

6. Largest Tip

    ```
    SELECT
        pickup."Zone" AS pickup_zone,
        dropoff."Zone" AS dropoff_zone,
        MAX(trips.tip_amount)
    FROM public.green_taxi_trips AS trips
    LEFT JOIN public.zones_lookup AS pickup ON trips."PULocationID" = pickup."LocationID"
    LEFT JOIN public.zones_lookup AS dropoff ON trips."DOLocationID" = dropoff."LocationID"
    WHERE lpep_pickup_datetime >= '2025-11-01'
        AND lpep_pickup_datetime < '2025-12-01'
        AND pickup."Zone" = 'East Harlem North'
    GROUP BY 1,2
    ORDER BY 3 DESC
    LIMIT 1;
    ```

    - Answer: Yorkville West

## Terraform

- Copy from [here](https://github.com/brettlyy/data-engineering-zoomcamp/blob/main/01-docker-terraform/terraform/terraform)
- Modify to create GCP Bucket and Big Query Dataset
- Use credentials key or set path in terminal

- main: [main.tf](./main.tf)
- variables: [variables.tf](./variables.tf)

- Run `terraform init` to get provider
- Run `terraform plan` to confirm changes
- Run `terraform apply -auto-approve` to apply and execute
- Run `terraform destroy`

7. What are the steps to download the provider plugin, generate proposed changes and auto-execute on plan, and then remove all resources?
    - terraform init, terraform apply -auto-approve, terraform destroy