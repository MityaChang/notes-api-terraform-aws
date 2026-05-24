# Staging Environment

This folder is a placeholder for the staging environment Terraform configuration.

## Setup

1. Copy the entire `dev/` folder contents into this directory
2. Modify the following for staging:

### backend.tf

- Change the S3 state key: `key = "stg/terraform.tfstate"`

### variables.tf

- Update `environment` default to `"stg"`
- Consider increasing instance sizes (e.g., `db.t3.small`)
- Adjust log retention if needed (e.g., 90 days)

### CI/CD

- Add a separate pipeline stage or branch rule for staging deployments
- Set `TF_VAR_db_password` for the staging database in CI variables

## Key Differences from Dev

| Setting             | Dev                     | Staging                    |
| ------------------- | ----------------------- | -------------------------- |
| Environment name    | `dev`                   | `stg`                      |
| State file key      | `dev/terraform.tfstate` | `stg/terraform.tfstate`    |
| RDS Multi-AZ        | `false`                 | `false` (optional: `true`) |
| Deletion protection | `false`                 | `true`                     |
| Lambda concurrency  | 5                       | 10+                        |
