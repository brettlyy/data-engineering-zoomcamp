# Terraform
Open-Source Infrastructure as Code

## Why Use It?
- Simple way to keep track of infra
- Easier collaboration and version control
- Reproducibility
- Ensure resources are removed

## How it Works

- Push terraform to services using a provider
- Providers are the code that allows tf to communicate and manage resources on services

## Key Commands

- `init`: get the providers we need
- `plan`: view what will be created/updated
- `apply`: do what is in the tf files
    - `-auto-approve`: optional flag to immediately execute on created plan
- `destroy`: remove everything defined in tf files

## Terraform - GCP Walkthrough

### Service Account Setup
- Need this to allow terraform to work within our GCP
- Use least privilege principle, but for this adding storage admin, compute admin, and bigquery admin for simplicity
    - to create cloud storagea and bigquery dataset
- Create a JSON key for the service account (keep secret)
- Save JSON to a keys folder in our local repo -- don't push to github

### Setup Terraform Files
- `main.tf` in repo
- Lookup and copy in google cloud provider: [Terraform Registry](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- Copy and paste template from "User Provider" and then add project and region configurations
    ```
    terraform {
    required_providers {
        google = {
        source = "hashicorp/google"
        version = "7.15.0"
        }
    }
    }

    provider "google" {
    project     = "terraform-demo-484217"
    region      = "us-central1"
    }
    ```
- Add credentials path:
    - can add to provider
    - better to export in terminal
        - `export GOOGLE_APPLICATION_CREDENTIALS="<path/to/your/service-account-authkeys>.json"`

**Note:** Can use `terraform fmt` in terminal for quick formatting

- Run `terraform init` to get the provider

### Create Bucket

[Terraform Registry](https://registry.terraform.io/providers/wiardvanrij/ipv4google/latest/docs/resources/storage_bucket)

- Add resource and configurations:
    ```
    resource "google_storage_bucket" "demo-bucket" {
        name          = "terraform-demo-484217-terra-bucket"
        location      = "US"
        force_destroy = true

        lifecycle_rule {
            condition {
            age = 1
            }
            action {
            type = "AbortIncompleteMultipartUpload"
            }
        }
        }
    ```

- Run `terraform plan`
    ![alt text](<Screenshot 2026-01-13 at 9.44.38 AM.png>)
- Run `terraform apply`
    ![alt text](<Screenshot 2026-01-13 at 9.46.08 AM.png>)

### Destroy Bucket

- Run `terraform destroy`

### Creating BigQuery Dataset

[Terraform Registry](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset)

- Add resource to `main.tf`
    ```
    resource "google_bigquery_dataset" "demo_dataset" {
        dataset_id = "demo_dataset"
    }
    ```

## Using Variables

With a `variables.tf` file to make configuration easier.

    ```
    variable "project" {
    description = "Project"
    default     = "terraform-demo-484217"
    }

    variable "region" {
    description = "Project Region"
    default     = "us-central1"
    }

    variable "location" {
    description = "GCP Location"
    default     = "US"
    }

    variable "bq_dataset_name" {
    description = "My BigQuery Dataset Name"
    default     = "demo_dataset"
    }

    variable "gcs_bucket_name" {
    description = "My Storage Bucket Name"
    default     = "terraform-demo-484217-terra-bucket"
    }

    variable "gcs_storage_class" {
    description = "Bucket Storage Class"
    default     = "STANDARD"
    }
```

- reference in `main.tf` like:
    `name          = var.gcs_bucket_name`

### More Stuff

- File - access files within repo
    - `file(var.credentials_path)`
    - Pass that in the `main.tf` file, can reference variable established in `variables.tf`

- Look at tf var files: allow different variable files you can use when applying