# Data Platforms

Tools that help manage the data lifecycle from ingestion to analytics.

- Data ingestion (extract from sources to your warehouse)
- Data transformation (cleaning, modeling, aggregating)
- Data orchestration (scheduling and dependency management)
- Data quality (built-in checks and validation)
- Metadata management (lineage, documentation)

For learning, we'll use [Bruin](https://getbruin.com/)

---

Full Walkthrough: [Bruin Github](https://github.com/bruin-data/bruin/tree/main/templates/zoomcamp)

---

## 1. What is a Data Platform | Bruin

Modern Data Stack Pulled Together
- ETL / ELT
- Orchestration (schedules, lineage, dags)
- Data Governance (metadata / quality)

### Pipeline Skeleton

The suggested structure separates ingestion, staging, and reporting, but you may structure your pipeline however you like.

The required parts of a Bruin project are:
- `.bruin.yml` in the root directory
- `pipeline.yml` in the `pipeline/` directory (or in the root directory if you keep everything flat)
- `assets/` folder next to `pipeline.yml` containing your Python, SQL, and YAML asset files

```text
zoomcamp/
├── .bruin.yml                              # Environments + connections (local DuckDB, BigQuery, etc.)
├── README.md                               # Learning goals, workflow, best practices
└── pipeline/
    ├── pipeline.yml                        # Pipeline name, schedule, variables
    └── assets/
        ├── ingestion/
        │   ├── trips.py                    # Python ingestion
        │   ├── requirements.txt            # Python dependencies for ingestion
        │   ├── payment_lookup.asset.yml    # Seed asset definition
        │   └── payment_lookup.csv          # Seed data
        ├── staging/
        │   └── trips.sql                   # Clean and transform
        └── reports/
            └── trips_report.sql            # Aggregation for analytics
```

---

## 2. Getting Started with Bruin

Install: `curl -LsSf https://getbruin.com/install/cli | sh`

Can insteall bruin extension in IDE

Run `bruin init default my_first_pipeline`
```text
my-first-pipeline/
├── .bruin.yml              # Environment and connection configuration
├── pipeline.yml            # Pipeline name, schedule, default connections
└── assets/
    ├── players.asset.yml   # Ingestr asset (data ingestion)
    ├── player_stats.sql    # SQL asset with quality checks
    └── my_python_asset.py  # Python asset
```

**Understanding the default template:**
- **`players.asset.yml`**: An ingestr asset that loads chess player data into DuckDB
- **`player_stats.sql`**: A SQL asset that transforms player data with quality checks
- **`my_python_asset.py`**: A simple Python asset that prints a message

Make sure we have duckdb installed

Creates `.bruin.yml` which also adds to gitignore. Never push this to github.
Some default, but you'd add your secrets here too.

`Assets` do something with data (ingest, transform, etc)

Example:
- Run [chess players asset](./../05-data-platforms/bruin-pipeline/assets/players.asset.yml)
    ```
    name: dataset.players
    type: ingestr

    parameters:
    destination: duckdb
    source_connection: chess-default
    source_table: profiles
    ```
- Creates new duckdb database and loads from source connection into db
- Can tweak variables like start and end date.

- Then can run [player stats]('./../../05-data-platforms/bruin-pipeline/assets/player_stats.sql) to create new table with player counts.

`pipeline.yml` is for configuring pipeline, default connection

### Core Concepts

- **Asset**: Any data artifact that carries value (table, view, file, ML model, etc.)
- **Pipeline**: A group of assets executed together in dependency order
- **Environment**: A named set of connection configs (e.g., `default`, `production`) so the same pipeline can run locally and in production
- **Connection**: Credentials to authenticate with external data sources & destinations
- **Pipeline run**: A single execution instance with specific dates and configuration

**Key concepts from this template:**
1. **Assets are the building blocks**: SQL, Python, or YAML files that represent data artifacts
2. **Dependencies define execution order**: `player_stats.sql` depends on `players`, so Bruin runs `players` first
3. **Quality checks are built-in**: `player_stats.sql` includes column checks (`not_null`, `unique`, `positive`)
4. **Connections are configured once**: `.bruin.yml` defines connections, `pipeline.yml` sets defaults

**Important**: Bruin CLI requires a git-initialized folder (uses git to detect project root); `bruin init` auto-initializes git if needed


### Configuration Files Deep Dive

#### `.bruin.yml`
- Defines environments (e.g., `default`, `production`)
- Contains connection credentials (DuckDB, BigQuery, Snowflake, etc.)
- Lives at the project root and **must be gitignored** because it contains credentials/secrets
  - `bruin init` auto-adds it to `.gitignore`, but double-check before committing anything

#### `pipeline.yml`
- `name`: Pipeline identifier (appears in logs, `BRUIN_PIPELINE` env var)
- `schedule`: When to run (`daily`, `hourly`, `weekly`, or cron expression)
- `start_date`: Earliest date for backfills
- `default_connections`: Platform-to-connection mappings
- `variables`: User-defined variables with JSON Schema validation


### Essential CLI Commands

The most common commands you'll use during development:

| Command | Purpose |
|---------|---------|
| `bruin validate <path>` | Check syntax and dependencies without running (fast!) |
| `bruin run <path>` | Execute pipeline or individual asset |
| `bruin run --downstream` | Run asset and all downstream dependencies |
| `bruin run --full-refresh` | Truncate and rebuild tables from scratch |
| `bruin lineage <path>` | View asset dependencies (upstream/downstream) |
| `bruin query --connection <conn> --query "..."` | Execute ad-hoc SQL queries |
| `bruin connections list` | List configured connections |
| `bruin connections ping <name>` | Test connection connectivity |

**Try these commands with your default pipeline:**

```bash
# Validate the pipeline (catches errors before running)
bruin validate .

# Run the entire pipeline
bruin run .

# Run a single asset
bruin run assets/my_python_asset.py

# Run an asset with its downstream dependencies
bruin run assets/players.asset.yml --downstream

# Check pipeline lineage
bruin lineage .

# Query the resulting table
bruin query --connection duckdb-default --query "SELECT * FROM dataset.player_stats"
```

---

## 3. Build Pipeline with NY Taxi

- Init project: `bruin init zoomcamp`
    - zoomcamp is prebuilt template for this

    See [readme](./../05-data-platforms/zoomcamp/README.md) for full setup details.

- 3-tiered pipeline structure:
    - ingestion
    - staging
    - reports

- Make sure `.bruin.yml` points to duckdb

- Fill out [pipeline yml](./../05-data-platforms/zoomcamp/pipeline/pipeline.yml)

- Add python script logic for ingestion. Added [here](./../05-data-platforms/zoomcamp/pipeline/assets/ingestion/trips.py)

Note: template has future incomplete assets so temp removed those to not have errors running the first one. I guess I could probably set to run a specific asset.

Note: using `requirements.txt` so bruin manages packages.

Run:
```bash
bruin run \
--start-date 2025-02-02T00:00:00.000Z \
--end-date 2025-02-02T23:59:59.999999999Z \
--environment default \
"/Users/brettly/dev/de-zoomcamp/05-data-platforms/zoomcamp/pipeline/assets/ingestion/trips.py"
```

- Setup seeds with payment type and run.
    - has built in quality checks for notnull and unique

- Then build staging and report layer as needed, with dependencies to previous steps.

- Setup `pipeline.yml` if haven't already. And run full thing.

### Running the full pipeline

```bash
# Validate structure and definitions
bruin validate ./pipeline/pipeline.yml

# Run with a small date range for testing
bruin run ./pipeline/pipeline.yml --start-date 2022-01-01 --end-date 2022-02-01

# Full refresh
bruin run ./pipeline/pipeline.yml --full-refresh

# Query results
bruin query --connection duckdb-default --query "SELECT COUNT(*) FROM ingestion.trips"
```

Open the pipeline YAML file in the Bruin panel and view the lineage tab to see all assets and their dependencies. Execution order:

1. Ingestion assets run first (trips + lookup, in parallel)
2. Staging asset runs after both ingestion assets complete
3. Report asset runs after staging completes

#### Materialization strategies summary

| Strategy | Behavior |
|----------|----------|
| `table` | Drop and recreate the table each time |
| `append` | Insert new data without touching existing rows |
| `merge` | Upsert based on key columns |
| `time_interval` | Delete rows in date range, then re-insert |
| `delete+insert` | Delete matching rows, then insert |
| `create+replace` | Create or replace the table |

## 4. Engineering with AI Agent

Bruin MCP (model context protocol) for direct integration.

Use with cursor or Claude.

Cursor config:
```
{
  "mcpServers": {
    "bruin": {
      "command": "bruin",
      "args": ["mcp"]
    }
  }
}
```

Claude:
`claude mcp add burin -- bruin mcp`

## 5. Deploy to Cloud

See instruction [here](https://github.com/bruin-data/bruin/tree/main/templates/zoomcamp#part-5-deploy-to-cloud)