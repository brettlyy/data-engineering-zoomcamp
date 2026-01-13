# Docker

Containeriation software that gives isolation between applications. Also allows for easier reproductibility and portability. 

**Example Command:** `docker run -it ubuntu`

- Opens interactive terminal with the ubuntu image
- If close and rerun it doesn't save what you did (i.e. installing Python)
- Each time you run it initializes a new docker image instance off of the Ubunto snapshot

## Stateless Containers
Any changes done inside a container will NOT be saved when container is killed and started again.

This is helpful because it doesn't impact your host system.

But the state is saved somewhere

## Managing Containers

View stopped containers: `docker ps -a`

Can, but not good practice to restart containers.

### Deleting Containers
They do take up space so delete old ones:
- `docker ps -aq` gives IDs
- ```docker rm `docker ps -aq` ``` deletes all old ones

## Other Notes

- Can set auto-delete when launching: `docker run -it --rm ubuntu`
- Note: containers and image save to Desktop
    - Container is what's run and can auto-delete
    - But the image will save for future (faster) use as well. So you can delete if you don't want it
- Can adjust entrypoint, like instead of python interactive, go to bash of python image:
    ```
    docker run -it \
        --rm \
        --entrypoint=bash \
        python:3.9.16-slim
    ```

## Volumes
Persist data and make files/data from host machine accessible in the container :)

What are they: Directories on Dockers host, managed by Dockers, and isolated from host

Use for:
- persist beyond conatiner lifecycle
- share and reuse among multiple containers (good for microservices and data piplines)
- seperate application code from data

### Execute Host Script in Docker

Map volume with `-v`

```
docker run -it \
    --rm \
    -v $(pwd)/test:/app/test \
    --entrypoint=bash \
    python:3.9.16-slim
```

/app/test is the directory in the image we want to pass our host's test folder to.

## Virtual Environments

Good for isolating packages so they aren't install globally.

I like to just use simple .venv `python -m venv .venv`

But another option is `uv`

### UV Dependencies
```
pip install uv
uv init --python=3.13
```

This will create a `pyproject.toml` file for managing dependencies and a `.python-version` file

Then add dependencies like: `uv add pandas pyarrow` which adds to your `pyproject.toml`

Run: `uv run python pipeline.py 10` (setup to run a pipeline with the 10 being the month input)

## Data Pipelines with Docker

Add a `Dockerfile` in your project to describe how you build image and container

Build from the python image, install the dependencies, and copy in pipeline.py file:
```
FROM python:3.13.11-slim

RUN pip install pandas pyarrow

WORKDIR /code
COPY pipeline.py .
```

Build Docker image: `docker build -t test:pandas .`
- test is image, pandas is tag

We can see the new image in Desktop:
![alt text](<Screenshot 2026-01-12 at 1.50.26 PM.png>)

Run image: `docker run -it --entrypoint=bash --rm test:pandas`

Add an entrypoint to `Dockerfile` so we don't have to do it manually each time:

- `ENTRYPOINT ["python", "pipeline.py"]`
- Rebuild with the same build command
    - It will only add new entrypoint, and use the old stuff that was cached
- Now run with the month parameter: `docker run -it --rm test:pandas 12`

### Use UV in Docker Image

- Update your Dockerfile to pull UV from existing image as well as your local files.

```
FROM python:3.13.11-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin

WORKDIR /code

COPY pyproject.toml .python-version uv.lock ./
RUN uv sync --locked

COPY pipeline.py .

ENTRYPOINT ["uv", "run", "python", "pipeline.py"]
```

- This pulls UV from an existing image
- running uv sync --locked makes sure it downloads the same dependencies as our virtual environment

Can skip the uv and run in the entrypoint by adding: `ENV PATH="/code/.venv/bin:$PATH"` after the workdir
    - This points to the right python to run.
    - so Entrypoint can be: `ENTRYPOINT ["python", "pipeline.py"]

## Running Postgres in Docker

- Use `-e` environment variables to configure application (user, password, database)
- Use `-v` volume mapping to persist data
    - Passing non-absolute path will use internal Docker volume
    - Data will persist after container is removed
    - Could use `$(pwd)/ny_taxi_postgres_data:/var/lib/postgresql/data \` instead if want to bind mount
- Use `-p` port mapping between host and container

### Nmaed Volumes vs. Bind Mount
- Named volume (name:/path): Managed by Docker, easier
- Bind mount (/host/path:/container/path): Direct mapping to host filesystem, more control

```
docker run -it --rm \
  -e POSTGRES_USER="root" \
  -e POSTGRES_PASSWORD="root" \
  -e POSTGRES_DB="ny_taxi" \
  -v ny_taxi_postgres_data:/var/lib/postgresql \
  -p 5432:5432 \
  postgres:18
```

### Accessing DB

Can use `pgcli`: `uv add --dev pgcli`

- The --dev flag marks this as a development dependency (not needed in production). It will be added to the [dependency-groups] section of pyproject.toml instead of the main dependencies section.
- Sync lock in Dockerfile won't install dev dependencies, only production

Connect to postgres: `uv run pgcli -h localhost -p 5432 -u root -d ny_taxi`

**Note:** CLI is running locally and connecting to postgres in container via the port mapping.

- Make sure you don't have any other postgres running locally.


## Data Ingestion into Docker Postgres

Parquet has schema, CSV will need to be given. Spark needs types given same as pandas.

In our example, we're:
1. downloading CSV files
2. read it in chunks with pandas
3. convert datetime columns
4. insert into PostgreSQL with SQLAlchemy

`uv add sqlalchemy psycopg2-binary`

- Setup SQLAlchemy connection:
    ```
    from sqlalchemy import create_engine
    engine = create_engine('postgresql://root:root@localhost:5432/ny_taxi')
    ```

- View schema that will be create: `print(pd.io.sql.get_schema(df, name='yellow_taxi_data', con=engine))`

- If want to create schema without inserting data, use `df.head(0).to_sql(name='yellow_taxi_data', con=engine, if_exisits='replace')`

    We now have the schema: ![alt text](<Screenshot 2026-01-12 at 9.26.22 PM.png>)

### Splitting Up Data
There are > 1.3M records in this dataframe which will take too much time to do it all in one batch, so we need to split up the data into batches. We can do this in our df setup:
```
df_iter = pd.read_csv(
    url,
    dtype=dtype,
    parse_dates=parse_dates,
    iterator=True,
    chunksize=100000
)
```

We loop through this iterator item to insert each chunk one at a time:
```
for chunk in tqdm(df_iter):
    chunk.to_sql(name='yellow_taxi_data', con=engine, if_exists='append')
```

**Note:** tqdm helps us see the progress, added it with `uv add tqdm`

#### Prettier Ingestion Loop

```
first = True

for df_chunk in df_iter:

    if first:
        # Create table schema (no data)
        df_chunk.head(0).to_sql(
            name="yellow_taxi_data",
            con=engine,
            if_exists="replace"
        )
        first = False
        print("Table created")

    # Insert chunk
    df_chunk.to_sql(
        name="yellow_taxi_data",
        con=engine,
        if_exists="append"
    )

    print("Inserted:", len(df_chunk))
```

### Other - Moving Jupyter to Python Script

```
uv run jupyter nbconvert --to=script notebook.ipynb
```

- Do cleanup of the output to make it into a true script.

**Note:** You can make the variables configurable when running in the terminal with `click`:
```
import click

@click.command()
@click.option('--user', default='root', help='PostgreSQL user')
@click.option('--password', default='root', help='PostgreSQL password')
@click.option('--host', default='localhost', help='PostgreSQL host')
@click.option('--port', default=5432, type=int, help='PostgreSQL port')
@click.option('--db', default='ny_taxi', help='PostgreSQL database name')
@click.option('--table', default='yellow_taxi_data', help='Target table name')
def ingest_data(user, password, host, port, db, table):
    # Ingestion logic here
    pass
```

Example usage:

```
uv run python ingest_data.py \
  --user=root \
  --password=root \
  --host=localhost \
  --port=5432 \
  --db=ny_taxi \
  --table=yellow_taxi_trips \
  --year=2021 \
  --month=1 \
  --chunksize=100000
```

Click also gives you access ot `uv run python ingest_data.py --help` to print help message

Sweet. We now have a python script to pull data and load to postgres.

## Setup in Docker Pipeline

Have a container hold the ingestion script and push the data to our postgres container.

- Have Dockerfile COPY in python data ingestion script
- Build with a tag: `docker build -t taxi_ingest:v001`

### Host Challenge with Ingestion Container

- Localhost is different in this container than it is for our local device.
- We solve for this by creating a network: `docker network create pg-network`
- When running a container, feed that they are part of the same network

Then run each on the network:
```
docker run -it --rm \
  -e POSTGRES_USER="root" \
  -e POSTGRES_PASSWORD="root" \
  -e POSTGRES_DB="ny_taxi" \
  -v ny_taxi_postgres_data:/var/lib/postgresql \
  -p 5432:5432 \
  --network=pg-network \
  --name pgdatabase \
  postgres:18
```

```
docker run -it --rm\
  --network=pg-network \
  taxi_ingest:v001 \
    --user=root \
    --password=root \
    --host=pgdatabase \
    --port=5432 \
    --db=ny_taxi \
    --table=yellow_taxi_trips
```

#### Important to Note
- We need to provide the network for Docker to find the Postgres container. It goes before the name of the image.
- Since Postgres is running on a separate container, the host argument will have to point to the container name of Postgres (pgdatabase).
- Names allow containers to find eachother in the network.

## PGAdmin

Can also run this in docker on the network for an easy UI:
```
docker run -it \
  -e PGADMIN_DEFAULT_EMAIL="admin@admin.com" \
  -e PGADMIN_DEFAULT_PASSWORD="root" \
  -v pgadmin_data:/var/lib/pgadmin \
  -p 8085:80 \
  --network=pg-network \
  --name pgadmin \
  dpage/pgadmin4
```

- Note the same network and a given name.
- Access at localhost:8085
- Connect new server on the `pgdatabase` connection

## Multi-Container Orchestration

Using Docker Compose

- Add `docker-compose.yaml` to your project
- Everything in docker compose is on same network so don't need to specify network name.
- run `docker-compose up`

```
services:
  pgdatabase:
    image: postgres:18
    environment:
      POSTGRES_USER: "root"
      POSTGRES_PASSWORD: "root"
      POSTGRES_DB: "ny_taxi"
    volumes:
      - "ny_taxi_postgres_data:/var/lib/postgresql"
    ports:
      - "5432:5432"

  pgadmin:
    image: dpage/pgadmin4
    environment:
      PGADMIN_DEFAULT_EMAIL: "admin@admin.com"
      PGADMIN_DEFAULT_PASSWORD: "root"
    volumes:
      - "pgadmin_data:/var/lib/pgadmin"
    ports:
      - "8085:80"



volumes:
  ny_taxi_postgres_data:
  pgadmin_data:
```

This is a clean slate, so need to run our ingestion script again.
- compose created a `postgres_default` network we need to run it on
    ```
    docker run -it --rm\
    --network=postgres_default \
    taxi_ingest:v001 \
        --user=root \
        --password=root \
        --host=pgdatabase \
        --port=5432 \
        --db=ny_taxi \
        --table=yellow_taxi_trips
    ```

- --rm should kill it as soon as it's done which is nice. And it should process and ingest the data into postgres. :) 

![Docker Network Visualization](<Screenshot 2026-01-12 at 11.01.55 PM.png>)
*This ends up being our final setup with docker in a network*

**Note:**
- We used docker compose for our tools - postgres and pgadmin
- We used dockerfile for our custom ingestion script, but we could have built that into docker compose