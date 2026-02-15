# Analytics Engineering Notes

Local setup guide [here](./../04-analytics-engineering/setup/local_setup.md)

Cloude setup guide [here](./../04-analytics-engineering/setup/cloud_setup.md)

## Local Setup

1. Install duckdb
 - great for local sql analysis
 - can install in programming syntax (`pip install duckdb` for python)
 - or can install CLi

    ```bash
    uv init
    uv add duckdb
    ```

2. Install dbt
    ```bash
    uv add dbt-duckdb
    ```

 - this adds dbt core and duckdb adapter


2a. 
**Note:** I deleted the given taxi folder so I could do the init from scratch.

`dbt init taxi_rides_ny`

3. Configure dbt profile
 - normally run `dbt init`, but [our folder](./../04-analytics-engineering/taxi_rides_ny/) is already setup.

 - Create `~/.dbt/profiles.yml` which tells dbt how to connect to your database. Fill in:
    ```
    taxi_rides_ny:
    target: dev
    outputs:
        # DuckDB Development profile
        dev:
        type: duckdb
        path: taxi_rides_ny.duckdb
        schema: dev
        threads: 1
        extensions:
            - parquet
        settings:
            memory_limit: '2GB'
            preserve_insertion_order: false

        # DuckDB Production profile
        prod:
        type: duckdb
        path: taxi_rides_ny.duckdb
        schema: prod
        threads: 1
        extensions:
            - parquet
        settings:
            memory_limit: '2GB'
            preserve_insertion_order: false

    # Troubleshooting:
    # - If you have less than 4GB RAM, try setting memory_limit to '1GB'
    # - If you have 16GB+ RAM, you can increase to '4GB' for faster builds
    # - Expected build time: 5-10 minutes on most systems
    ```
4. Ingest data using [provided script](./../04-analytics-engineering/taxi_rides_ny/data_ingestion.py)

 - this script downloads the data, creates the prod schema, and loads the raw data into DuckDB.

5. Test dbt connection: `dbt debug`

5a. Can also test in DuckDB local UI

```
duckdb -ui
```

Copy db path, and add as attached database

Make sure to close this when not using because could cause some issues if running two instances at once while working with data.

## Intro to Analytics Engineering

Make sure the business realities are reflected in the data insights. Data modeling with SWE best practices.

Production quality and testing moving beyond speed of delivery.

Data modeling focused on ease to maintain and business value.

## Intro to Data Modeling

Moving modeling after the storage layer - ELT - transform while in data warehouse. Faster and more flexible. Available now that storage cost is so efficient.

### Kimball's Dimensional Modeling

![alt text](<Screenshot 2026-02-08 at 8.54.30 AM.png>)

Star Schema - fact = verbs; dimension = nouns

Bronze, Silver, Gold
Staging, Processing, Presentation

- Staging - raw data
- Processing - into data models, focus on standards and efficiency
- Presentation - expose to business stakeholder

## What is DBT

Use SQL for SWE best practices
- Modularity
- Portability
- CI/CD
- Documentation

Sits on top of data warehouse

### How does it work
Each model is a:
- SQL file
- Select statement
- DBT run compiles and runs in datawarehouse

### Core vs. Cloud

Core:
- Open Source
- CLI interface to run commands locally

Cloud:
- SaaS
- IDE on web or cloud CLI
- Admin APIs
- **Semantic Layer**
- Some others

[Comparison Page](https://www.getdbt.com/product/how-dbt-platform-compares)

### dbt Fusion

Newer offering, more developer friendly and support.
But not supported by DuckDB

## DBT Project Structures

### analyses

- Place for non-production SQL scripts

### dbt_project.yml

- must have for a project
- hold default variables
- for dbt core, your profile should match one in `.dbt/profiles`

### macros

- behave like python functions, resuable logic
- hold logic in standard place

### README.md

- same like a github project

### seeds

- quick way to ingest flat files when you don't have a more permanent solution yet

### snapshots

- snapshots within dbt for history tracking if can't have it in a permanent solution yet

### tests

- SQL files as assertions
- singular test: build fails if returns > 0 rwos

### models

- Holds SQL or Python logic
- 3 sub-folders suggested
    - staging (data sources or staged with minor cleaning)
    - intermediate (non-raw data but not yet finalized)
    - marts (data for end user consumption)


## Setting up Sources

models/staging

create `sources.yml`
    ```
    version: 2

    sources:
    - name: raw_data
        description: "Raw data sources for NYC taxi data"
        database: taxi_rides_ny
        schema: prod
        tables:
        - name: yellow_tripdata
        - name: green_tripdata
    ```

created sql files: stg_green_tripdata.sql and stg_yellow_tripdata.sql

- Keep 1:1 with sourece for the most part

## dbt Models

This is where you'll switch to fully exploring and understanding data, and working with owners to understand the data and with stakeholders to start working towards full data models.

Setup fct and dim tables.
- dim_vendors
- dim_locations
- fct_trips

Key is understanding business logic. Like that green taxis are a special license focused on areas outside of manhattan.

setup trips table to hold both green and yellow
- do in intermediate model so fact trips can be simpler.


### Referencing files
If refering yaml, use source
`FROM {{ source('raw_data', 'green_tripdata') }}`

If referencing another model, use ref
`from {{ ref('stg_green_tripdata') }}`

Made some changes to match up fields for union.
So need to run `dbt run` again to have that reflected.

## dbt seeds and macros

Setup dim tables with seeds. good for local testing when don't have somthing in a warehouse

want it to be small - goes to git so must be public safe

- Add CSV to seeds/ 
- run `dbt seed`
- setup dimensions table in models/marts/

Setup macros for getting vendor names
- reusable across project
- like a function

```
{% macro get_vendor_names(vendor_id) %}
case
    when {{vendor_id}} = 1 then 'Creative Mobile Technologies, LLC'
    when {{vendor_id}} = 2 then 'VeriFone Inc.'
    when {{vendor_id}} = 4 then 'Unknown Vendor'
end
{% endmacro %}
```

## Documentation

- Can add in `yml` files:
    - table descriptions
    - column desriptions and dtypes
    - additional meta tags (pii, owner, importance, formatting, etc.)

common to have a `schema.yml` in your models folders

`dbt docs generate` builds a JSON of all your DBT documentation.
`dbt docs serve` launches a web ui with technical data definition support

## dbt Tests

Detect errors in time
understand why and how to fix

Issues could be underlying issue data or dbt/sql bug.

### Singular Tests
Place in tests/ directory.
simple sql statements
IF return any rows there is an error

### Generic Tests
Defined in `yml`
include `tests` sections
    - unique
    - not null
    - accepted values
    - relationship

### Custom Generic Tests
Can write custom and store in tests/generic/ directory

### Unit Tests
v 1.8 and on
provide input data for testing
defensively test

### Model Contracts

Explicit definitions of a model's columns, data types, and constraints

yml models:
```
config:
    contract:
        enforced: true
```

#### From Claude:

- Contracts are preventive - they catch structural issues at build time
- Tests are detective - they check data quality after the model runs
- Use contracts for "shape" guarantees (schema, types), tests for "content" quality (uniqueness, relationships, values)
- They're complementary: contracts ensure the foundation is solid, tests verify the data within that foundation makes sense

### Source Freshness
Can include `freshness` setting in `yml`
Running `dbt source freshness` to check

## dbt Packages

[dbt Hub](https://hub.getdbt.com)
Some good ones in github good too, just understand them well

- dbt_utils: a lot of out of the box functions
- dbt_project_evaluator: best practices score
- codegen: auto generate columns in yaml file
    - or provide yml file and it generates SQL code
- audit_helper: refactor old SQL into new script, make sure both models identical
- dbt_expectations: prebuilt tests

Some for specific warehouses.

### Using a Package

- Create packages.yml in project
    ```
    packages:
    - package: dbt-labs/dbt_utils
        version: 1.3.3
    ```
- run `dbt deps`
- this will add the package with everything

Example: generate a surrogate key

    ```
    {{ dbt_utils.generate_surrogate_key([
        'vendor_id',
        'pickup_datetime',
        'pickup_location_id',
        'service_type'
    ]) }} as trip_id
    ```

## dbt Commands

### Setup
- dbt init: initialize project, create structure
- dbt debug: checks project.yml for valid data connection

### Features
- dbt seed: ingest all seeds CSVs 
- dbt snapshot: run snapshots
- dbt source freshness: check if stale or not based on yml
- dbt docs generate: for documentation website
- dbt docs servce: browse doc site
    - find way to host site
- dbt clean: get rid of things defined in project.yml
- dbt deps: readd dependencies
- dbt compile: compiles all code sent to your database (no jinja)

### Key Ones
- dbt run: materializes models
- dbt test: runs all tests in project
- dbt build: run + test + seed + snapshot + UDFs in correct order
- dbt retry: from build failure point

### Command Flags

- dbt --help or dbt -h
- dbt --version
- dbt run --full-refresh: do full refresh instead of incremental model
- dbt run --fail-fast: quicker strict fail
- dbt run --target (-t): override prod vs dev for example
- dbt run --select {foo}: example run specific model
    - dbt run --select stg_green_tripdata
    - dbt run --select +{foo}: include + sign to include preqreqs
    - dbt run --select {foo}+: include everything after
    - dbt run --select +{foo}+

    - can select certain tags, directories. very flexible
    - can use select state:new or state:modified
        - move artifacts (e.g. manifest.json) to subfolder
        - point state to new source

