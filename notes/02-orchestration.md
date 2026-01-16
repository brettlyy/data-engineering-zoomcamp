# Workflow Orchestration

What is it? An orchestrator keeps tools (databases, cloud, code, etc.) working together on a routine schedule or based on events that happen. 

For this module, we'll use Kestra.

## Install Kestra

- Add kestra postgres database and kestra to a `docker-compose.yaml` file
- We're also still leaving the same postgres and pgadmin as module 1, but adding items from below
    - Kestra postgres will hold Kestra's data, with our OG postgres having the pipeline data
    ```
    kestra_postgres:
    image: postgres:18
    volumes:
      - kestra_postgres_data:/var/lib/postgresql
    environment:
      POSTGRES_DB: kestra
      POSTGRES_USER: kestra
      POSTGRES_PASSWORD: k3str4
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      interval: 30s
      timeout: 10s
      retries: 10

  kestra:
    image: kestra/kestra:v1.1
    pull_policy: always
    # Note that this setup with a root user is intended for development purpose.
    # Our base image runs without root, but the Docker Compose implementation needs root to access the Docker socket
    # To run Kestra in a rootless mode in production, see: https://kestra.io/docs/installation/podman-compose
    user: "root"
    command: server standalone
    volumes:
      - kestra_data:/app/storage
      - /var/run/docker.sock:/var/run/docker.sock
      - /tmp/kestra-wd:/tmp/kestra-wd
    environment:
      KESTRA_CONFIGURATION: |
        datasources:
          postgres:
            url: jdbc:postgresql://kestra_postgres:5432/kestra
            driverClassName: org.postgresql.Driver
            username: kestra
            password: k3str4
        kestra:
          server:
            basicAuth:
              username: "admin@kestra.io" # it must be a valid email address
              password: Admin1234
          repository:
            type: postgres
          storage:
            type: local
            local:
              basePath: "/app/storage"
          queue:
            type: postgres
          tasks:
            tmpDir:
              path: /tmp/kestra-wd/tmp
          url: http://localhost:8080/
    ports:
      - "8080:8080"
      - "8081:8081"
    depends_on:
      kestra_postgres:
        condition: service_started
    ```

- Run `docker-compose up`
- Can access ketra in port 8080 based on docker compose file: `http://localhost:8080`

## Kestra Concepts

- id and namespace are locked once saved
- flows work off of tasks with given properties
- inputs allow you to pass data to workflow at start of execution
- Variables are key-value pair, pass like `{{ inputs.name }}` in expressions
    - Wrap expressions in "render" to recursively render, e.g.:
        ```
        tasks:
            - id: hello_message
                type: io.kestra.plugin.core.log.Log
                message: "{{ render(vars.welcome_message) }}"
    ``
- Use `return` task to output and use later
    - Use via `{{ outputs.{task_id}.value }}`
- pluginDefaults: define task properties in one place
    - e.g. define all logging with a level of Error rather than the default
- Trigger lets you define schedule or event trigger and inputs
    - set `disabled: true` to prevent auto-running scheulde/event
- Concurrency: how many of this type of workflow can run at the same time and what it should do if multiple are running.
    - Limit and Behavior

### Orchestrating Python in Kestra

- Can write python code directly in workflow with script task if small.
- Commands tasks allows you to execute file
- Kestra spins up docker container to run python code dedicated to that task
    - Specify dependencies, specify specific container if needed
- Kestra library allows returning python results as output

## ETL with Kestra
Pull from NY Taxi, transform, and load to Postgres

- Create new flow in Kestra
- [Taxi data source](https://github.com/DataTalksClub/nyc-tlc-data/releases)
- Add inputs to make handling which data source easier (yellow vs green, year, month)
    - Using `SELECT` type to select on execute
    ```
    inputs:
        - id: taxi
            type: SELECT
            displayName: Select taxi type
            values: [yellow, green]
            defaults: green

        - id: year
            type: SELECT
            displayName: Select year
            values: ["2019", "2020"]
            defaults: "2019"

        - id: month
            type: SELECT
            displayName: Select month
            values: ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"]
            defaults: "01"
    ```
- Use variables for repeatable uses:
    ```
    variables:
        file: "{{inputs.taxi}}_tripdata_{{inputs.year}}-{{inputs.month}}.csv"
        staging_table: "public.{{inputs.taxi}}_tripdata_staging"
        table: "public.{{inputs.taxi}}_tripdata"
        data: "{{outputs.extract.outputFiles[inputs.taxi ~ '_tripdata_' ~ inputs.year ~ '-' ~ inputs.month ~ '.csv']}}"
    ```
### Extraction Tasks
- Set Labels: adds labels to execution for our benefit of looking back at execution

```
tasks:
    - id: set_label
        type: io.kestra.plugin.core.execution.Labels
        labels:
        file: "{{render(vars.file)}}"
        taxi: "{{inputs.taxi}}"
```

- Extract using `shell.Commands` task
    - wget to download file and gunzip to unzip the file
    - use our variables where possible
    - using `taskRunner: `io.kestra.plugin.core.runner.Process` to avoid spinning up full container to run this

    ```
    - id: extract
        type: io.kestra.plugin.scripts.shell.Commands
        outputFiles:
            - "*.csv"
        taskRunner:
            type: io.kestra.plugin.core.runner.Process
        commands:
            - wget -qO- https://github.com/DataTalksClub/nyc-tlc-data/releases/download/{{inputs.taxi}}/{{render(vars.file)}}.gz | gunzip > {{render(vars.file)}}
    ```
    - using render in there to recursively use variables and get full string

### Setup Tables
- Create postgres tables
    - use `postgresql.Queries` plugin at bottom of file for default values
        - **Note:** we should be using secrets for this, but hardcoding for simplicity
        ```
        pluginDefaults:
            - type: io.kestra.plugin.jdbc.postgresql
                values:
                url: jdbc:postgresql://pgdatabase:5432/ny_taxi
                username: root
                password: root
        ```
    - Feed in schema to create green taxi table, including new rows for unique_id and filename
        ```
        - id: green_create_table
            type: io.kestra.plugin.jdbc.postgresql.Queries
            sql: |
            CREATE TABLE IF NOT EXISTS {{render(vars.table)}} (
                unique_row_id          text,
                filename               text,
                VendorID               text,
                lpep_pickup_datetime   timestamp,
                lpep_dropoff_datetime  timestamp,
                store_and_fwd_flag     text,
                RatecodeID             text,
                PULocationID           text,
                DOLocationID           text,
                passenger_count        integer,
                trip_distance          double precision,
                fare_amount            double precision,
                extra                  double precision,
                mta_tax                double precision,
                tip_amount             double precision,
                tolls_amount           double precision,
                ehail_fee              double precision,
                improvement_surcharge  double precision,
                total_amount           double precision,
                payment_type           integer,
                trip_type              integer,
                congestion_surcharge   double precision
            );
        ```

    - Create green taxi staging table
        ```
        - id: green_create_staging_table
            type: io.kestra.plugin.jdbc.postgresql.Queries
            sql: |
            CREATE TABLE IF NOT EXISTS {{render(vars.staging_table)}} (
                unique_row_id          text,
                filename               text,
                VendorID               text,
                lpep_pickup_datetime   timestamp,
                lpep_dropoff_datetime  timestamp,
                store_and_fwd_flag     text,
                RatecodeID             text,
                PULocationID           text,
                DOLocationID           text,
                passenger_count        integer,
                trip_distance          double precision,
                fare_amount            double precision,
                extra                  double precision,
                mta_tax                double precision,
                tip_amount             double precision,
                tolls_amount           double precision,
                ehail_fee              double precision,
                improvement_surcharge  double precision,
                total_amount           double precision,
                payment_type           integer,
                trip_type              integer,
                congestion_surcharge   double precision
            );
        ```

        - Want this staging table to delete each time after we load to the main table so need to truncate:
            ```
            - id: green_truncate_staging_table
                type: io.kestra.plugin.jdbc.postgresql.Queries
                sql: |
                TRUNCATE TABLE {{render(vars.staging_table)}};
            ```
### Load to Staging Table
- Use `CopyIn` task to load from CSV into staging table
    ```
    - id: green_copy_in_to_staging_table
        type: io.kestra.plugin.jdbc.postgresql.CopyIn
        format: CSV
        from: "{{render(vars.data)}}"
        table: "{{render(vars.staging_table)}}"
        header: true
        columns: [VendorID,lpep_pickup_datetime,lpep_dropoff_datetime,store_and_fwd_flag,RatecodeID,PULocationID,DOLocationID,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,improvement_surcharge,total_amount,payment_type,trip_type,congestion_surcharge]
    ```

### Transform - Add new variables
- Use query update to add in id and filename
    - Using md5 hash on all those properties
    ```
    - id: green_add_unique_id_and_filename
    type: io.kestra.plugin.jdbc.postgresql.Queries
    sql: |
        UPDATE {{render(vars.staging_table)}}
        SET 
        unique_row_id = md5(
            COALESCE(CAST(VendorID AS text), '') ||
            COALESCE(CAST(lpep_pickup_datetime AS text), '') || 
            COALESCE(CAST(lpep_dropoff_datetime AS text), '') || 
            COALESCE(PULocationID, '') || 
            COALESCE(DOLocationID, '') || 
            COALESCE(CAST(fare_amount AS text), '') || 
            COALESCE(CAST(trip_distance AS text), '')      
        ),
        filename = '{{render(vars.file)}}';
    ```

### Merge data to final table
- Use query merge
    - Merge using the unique row id to insert when no match (not updating)
    ```
    - id: green_merge_data
    type: io.kestra.plugin.jdbc.postgresql.Queries
    sql: |
        MERGE INTO {{render(vars.table)}} AS T
        USING {{render(vars.staging_table)}} AS S
        ON T.unique_row_id = S.unique_row_id
        WHEN NOT MATCHED THEN
        INSERT (
            unique_row_id, filename, VendorID, lpep_pickup_datetime, lpep_dropoff_datetime,
            store_and_fwd_flag, RatecodeID, PULocationID, DOLocationID, passenger_count,
            trip_distance, fare_amount, extra, mta_tax, tip_amount, tolls_amount, ehail_fee,
            improvement_surcharge, total_amount, payment_type, trip_type, congestion_surcharge
        )
        VALUES (
            S.unique_row_id, S.filename, S.VendorID, S.lpep_pickup_datetime, S.lpep_dropoff_datetime,
            S.store_and_fwd_flag, S.RatecodeID, S.PULocationID, S.DOLocationID, S.passenger_count,
            S.trip_distance, S.fare_amount, S.extra, S.mta_tax, S.tip_amount, S.tolls_amount, S.ehail_fee,
            S.improvement_surcharge, S.total_amount, S.payment_type, S.trip_type, S.congestion_surcharge
        );
    ```

### Add Yellow Taxi Data
Green and yellow taxi data have different schemas, need to treat them different using `IF` tasks, like:
```
- id: if_yellow_taxi
    type: io.kestra.plugin.core.flow.If
    condition: "{{inputs.taxi == 'yellow'}}"
    then:
        -id: yellow_create_table
```

- Add the yellow setup under all this yellow if
- Add green setup under a green if

### Other Additions
- purge_files task
    - each time we run this it's downloading and storing CSV in execution history
    - use `storage.PurgeCurrentExecutionFiles` to clean up the memory
    - Add this at the end of the flow before plugindefaults

    ```
    - id: purge_files
        type: io.kestra.plugin.core.storage.PurgeCurrentExecutionFiles
        description: This will remove output files. If you'd like to explore Kestra outputs, disable it.
    ```

- can also use `taskCache: enabled: true` to use cached if running again under the extract task
    - but not if you're purging

        
## Schedule & Backfills

### Scheduling a Trigger
- Need some changes from prior example:
    - Remove year and month inputs, handle in scheduling
    - Use triggers instead (notice the passing of inputs for taxi color):
        ```
        triggers:
            - id: green_schedule
                type: io.kestra.plugin.core.trigger.Schedule
                cron: "0 9 1 * *"
                inputs:
                taxi: green

            - id: yellow_schedule
                type: io.kestra.plugin.core.trigger.Schedule
                cron: "0 10 1 * *"
                inputs:
                taxi: yellow
      ```
    - Access trigger information with expressions like `{{trigger.date | date('yyyy-MM')}}`

### Scheduling a Backfill
Run for previous months like they WOULD have run

- Make sure date range covers when the trigger would have been executed
    - Like ours runs monthly at 9AM, so need to include 9AM
    - Don't just run through midnight of the second month

   ![alt text](<Screenshot 2026-01-15 at 12.22.58 PM.png>) 

## ETL vs ELT

- Benefit comes in the example of the yellow taxi dataset - the transformations ran super slow because it was so much.
- ELT would let us load the data to a data lake and utilize BigQuery to make the transformation
    - BigQuery directly references and uses data from data lake without transforming original data

## Using Kestra with GCP

### Managing Secrets
Few options for managing secrets:
- Secrets inside UI if you have enterprise edition
    - bound to namespaces
    - access via expression: `{{ secret('mysecret') }}`
- Set as docker environment variable for open-source in `docker-compose.yml`
    ```
    environment:
        `SECRET_MYSECRET: {base64secret}`
    ```
    - Must base64 encode
- Store in .env file
    - Store raw
    - Create .env_encoded with base64 encoding (terminal command makes this easier)
    - Reference .env_encoded in docker-compose, not in environment
        ```
        env_file:
            - .env_encoded
        ```


#### Using service account json as secret
- Save service account as `service-account.json`
- Base64 encode it and save it to `.env_encoded`
    `echo SECRET_GCP_SERVICE_ACCOUNT=$(cat service-account.json | base64 -w 0) >> .env_encoded`
- Add env to kestra docker-compose:
    ```
    kestra:
      env_file: .env_encoded
    ```
- Access inside kestra with: `"{{ secret('GCP_SERVICE_ACCOUNT') }}"`


### Creating KV Store (Key-Value)
We will use these an inputs for our pipeline
- Run as a workflow adding our key-values:
    ```
    id: setup_zoomcamp_kv
    namespace: zoomcamp

    tasks:
    - id: gcp_project_id
        type: io.kestra.plugin.core.kv.Set
        key: GCP_PROJECT_ID
        kvType: STRING
        value:  data-dino

    - id: gcp_location
        type: io.kestra.plugin.core.kv.Set
        key: GCP_LOCATION
        kvType: STRING
        value: us-central1

    - id: gcp_bucket_name
        type: io.kestra.plugin.core.kv.Set
        key: GCP_BUCKET_NAME
        kvType: STRING
        value: data-dino-ny-taxi

    - id: gcp_dataset
        type: io.kestra.plugin.core.kv.Set
        key: GCP_DATASET
        kvType: STRING
        value: ny_taxi
    ```

### Setup GCP Resources
Do this using key-value pairs and service account like a terraform. We could skip this is we would've saved our setup built with terraform.
    ```
    id: gcp_setup_resources
    namespace: zoomcamp

    tasks:
    - id: create_gcs_bucket
        type: io.kestra.plugin.gcp.gcs.CreateBucket
        ifExists: SKIP
        storageClass: REGIONAL
        name: "{{kv('GCP_BUCKET_NAME')}}"

    - id: create_bq_dataset
        type: io.kestra.plugin.gcp.bigquery.CreateDataset
        name: "{{kv('GCP_DATASET')}}"
        ifExists: SKIP

    pluginDefaults:
    - type: io.kestra.plugin.gcp
        values:
        serviceAccount: "{{secret('GCP_SERVICE_ACCOUNT')}}" 
        projectId: "{{kv('GCP_PROJECT_ID')}}"
        location: "{{kv('GCP_LOCATION')}}"
        bucket: "{{kv('GCP_BUCKET_NAME')}}"
    ```

### Load Data into Bigquery

Works very similar to the postgres flow, but first loading to GCS and setting up flows from GCS to BigQuery.

- Update variables to point to GCP
- Upload to GCS using `gcp.gcs.Upload` task
    ```
    - id: upload_to_gcs
        type: io.kestra.plugin.gcp.gcs.Upload
        from: "{{render(vars.data)}}"
        to: "{{render(vars.gcs_file)}}"~
    ```

- Note, using pluginDefaults for gcp with our KV store:
    ```
    pluginDefaults:
    - type: io.kestra.plugin.gcp
        values:
        serviceAccount: "{{kv('GCP_CREDS')}}"
        projectId: "{{kv('GCP_PROJECT_ID')}}"
        location: "{{kv('GCP_LOCATION')}}"
        bucket: "{{kv('GCP_BUCKET_NAME')}}"
    ```

- Replace postgres tasks with `bigquery.Query` tasks
    - Create tables with bigquery syntax
    - With staging table (bq_{color}_table_ext) include options to load in data from GCS:
        ```
        OPTIONS (
              format = 'CSV',
              uris = ['{{render(vars.gcs_file)}}'],
              skip_leading_rows = 1,
              ignore_unknown_values = TRUE
          )
        ```

- I find it interesting in the example the staging tables are loaded with the month rather than just a generic staging table that is cleared out each run. 
    - So there is an external, staging (with unique ID), and final partitioned? Seems off but I guess just quick for a tutorial

**Summary:** So new flow is the same as postgres, just first saving to GCS and having data load directly as part of temporary staging table creation. It should work faster.

### Schedule & Backfill with GCP
This works the same as with the postgres example.

## Kestra & AI
- Add a new ai block to docker-compose under `KESTRA_CONFIGURATION`
- Add LLM API key (like Gemini) as an env variable in docker-compose
    ```
    ai:
        type: gemini
        gemini:
            model-name: gemini-2.5-flash
            api-key: ${GEMINI_API_KEY}
    ```

- Use AI Copilot within Kestra UI

### Retrieval Augmented Generation (RAG)
Provide more context to AI by allowing it to ingest useful info/data. Looking at example of asking an LLM about the Kestra 1.1 release.

The basic flow is to store important context in a vector database and have your model go fetch that info when needed (add context to prompt).

#### The Process:
- Ingest documents: Load documentation, release notes, or other data sources
- Create embeddings: Convert text into vector representations using an LLM
- Store embeddings: Save vectors in Kestra's KV Store (or a vector database)
- Query with context: When you ask a question, retrieve relevant embeddings and include them in the prompt
- Generate response: The LLM has real context and provides accurate answers

- Add `embeddings` with actual release notes as with a `ai.rag.IngestDocument`
    - Use KV Store as embeddings type
    ```
    - id: ingest_release_notes
        type: io.kestra.plugin.ai.rag.IngestDocument
        description: Ingest Kestra 1.1 release notes to create embeddings
        provider:
        type: io.kestra.plugin.ai.provider.GoogleGemini
        modelName: gemini-embedding-001
        apiKey: "{{ kv('GEMINI_API_KEY') }}"
        embeddings:
        type: io.kestra.plugin.ai.embeddings.KestraKVStore
        drop: true
        fromExternalURLs:
        - https://raw.githubusercontent.com/kestra-io/docs/refs/heads/main/content/blogs/release-1-1.md
    ```

- Use `ai.rag.ChatCompletion` now, with acceess to embedding and new systemMessage for question:
    ```
    - id: chat_with_rag
        type: io.kestra.plugin.ai.rag.ChatCompletion
        description: Query about Kestra 1.1 features with RAG context
        chatProvider:
            type: io.kestra.plugin.ai.provider.GoogleGemini
            modelName: gemini-2.5-flash
            apiKey: "{{ kv('GEMINI_API_KEY') }}"
        embeddingProvider:
            type: io.kestra.plugin.ai.provider.GoogleGemini
            modelName: gemini-embedding-001
            apiKey: "{{ kv('GEMINI_API_KEY') }}"
        embeddings:
            type: io.kestra.plugin.ai.embeddings.KestraKVStore
        systemMessage: |
            You are a helpful assistant that answers questions about Kestra.
            Use the provided documentation to give accurate, specific answers.
            If you don't find the information in the context, say so.
        prompt: |
            Which features were released in Kestra 1.1? 
            Please list at least 5 major features with brief descriptions.
    ```

## Deploying Kestra in Production

[Kestra Guide](https://kestra.io/docs/installation/gcp-vm?clid=eyJpIjoiSGh1UURXR0RqUzRwT3pIWVJ0b2JXIiwiaCI6IiIsInAiOiIvZGUtem9vbWNhbXAvZ2NwLWluc3RhbGwiLCJ0IjoxNzY4NTQ0MTY4fQ.298GRazycoD6t1zdEkMshQSDHNEa5zoRSsD3_IihrGQ)

- Create a General Purpose VM with at least 4GiB of memory and 2 vCPUs
    - Use Ubuntu image
    - Allow HTTPS traffic
- Install Docker via SSH - [Docker Installation](https://docs.docker.com/engine/install/ubuntu/)
- Download official Kestra docker-compose:
    ```
    curl -o docker-compose.yml \
    https://raw.githubusercontent.com/kestra-io/kestra/develop/docker-compose.yml
    ```
- Edit with vim and set `basic-auth: enabled: true` to secure Kestra
- See guide for firewall setup pictures
- Launch Cloud SQL because ou need a postgres database running alongside Kestra on the instance
    - Dev can use database running via docker
    - Production should use a managed Cloud SQL database
- Enable VM connection to the database: uncheck public and check private
    - follow instructions in guide for setup
- Can uncheck deletion protection if just testing and don't need it
- Create a user account
- Create kestra database
- Update docker-compose file and point to postgres under the `datasources:`
    ```
    datasources:
        postgres:
            url: jdbc:postgresql://<your-db-external-endpoint>:5432/<db_name>
            driver-class-name: org.postgresql.Driver
            username: <your-username>
            password: <your-password>
    ```
- And delete the depends_on section at the end of the YAML file:
- Remove the postgres docker service from docker-compose

- You can also update to use GCS for storage
    - edit to `storage: type: gcs`
        - point to your bucket and proejct id
        - point to your service account

## Other Kestra Things

- Use git: [guide](https://go.kestra.io/de-zoomcamp/git)
- Deploy with GitHub Actions: [guide](https://go.kestra.io/de-zoomcamp/deploy-github-actions)