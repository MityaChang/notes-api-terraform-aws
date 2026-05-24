# Production Environment

This folder is a placeholder for the production environment Terraform configuration.

## Setup

1. Copy the entire `dev/` folder contents into this directory
2. Modify the following for production:

### backend.tf

- Change the S3 state key: `key = "prod/terraform.tfstate"`
- Consider using a separate S3 bucket for production state

### variables.tf

- Update `environment` default to `"prod"`
- Increase instance sizes (e.g., `db.t3.small` or `db.t3.medium`)
- Increase Lambda memory/timeout as needed

### main.tf (module settings to change)

| Module  | Setting                | Recommended for Prod |
| ------- | ---------------------- | -------------------- |
| storage | `multi_az`             | `true`               |
| storage | `deletion_protection`  | `true`               |
| storage | `skip_final_snapshot`  | `false`              |
| logging | `retention_days`       | `365`                |
| compute | `reserved_concurrency` | `20+`                |
| compute | `memory_size`          | `512` or higher      |

### Security hardening for production

- Enable RDS Performance Insights
- Enable VPC Flow Logs
- Enable CloudWatch KMS encryption
- Enable RDS IAM authentication
- Consider adding API Gateway authorization (Cognito/API keys)
- Remove checkov inline skips for production-grade checks

### CI/CD

- Add a separate pipeline stage with stricter rules (e.g., only deploy from `main` branch)
- Use a separate IAM role with limited blast radius
- Set production-specific CI variables (e.g., `TF_VAR_db_password`)
- Require approval from multiple reviewers before apply
