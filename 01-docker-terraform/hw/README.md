# Homework for Module 1

## Relevant Files

- [Docker Compose File](./docker-compose.yaml) for postgres and pgadmin
- [Python script](./ingest_data.py) for ingesting and loading data to postgres database
- [Dockfile](./Dockerfile) that copies in python scripts for ETL within docker network
- [Main Terraform file](./main.tf) for launching gcs bucket and bigquery dataset
- [Variables Terraform file](./variables.tf) with terraform variables used in `main.tf`

## Steps File

[steps.md](./steps.md) has notes on the steps I used for the homework, including SQL statements run.