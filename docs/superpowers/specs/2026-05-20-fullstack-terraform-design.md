# Full-Stack REST API + Terraform on AWS — Design Spec

## Summary

A production-ready CRUD REST API for "Notes" built with Python/FastAPI, deployed on AWS Lambda + API Gateway, backed by RDS PostgreSQL, provisioned entirely via modular Terraform, with a GitLab CI pipeline for plan/deploy workflow.

## Technology Choices & Justifications

| Component | Choice | Justification |
|-----------|--------|---------------|
| Language/Framework | Python 3.11 + FastAPI | Lightweight, fast to build, excellent for Lambda via Mangum adapter |
| Compute | AWS Lambda + API Gateway (HTTP API) | Serverless, pay-per-request, zero idle cost, no infrastructure to manage |
| Storage | RDS PostgreSQL (db.t3.micro) | Relational, encryption at rest, demonstrates proper network isolation, free-tier eligible |
| Deployment | Container image → ECR → Lambda | Satisfies "build/publish container images" requirement, reproducible builds |
| API Exposure | API Gateway HTTP API | Cheaper than REST API type, built-in Lambda integration, managed TLS |
| Logging | CloudWatch Logs | Native integration with Lambda and RDS, no extra infrastructure |
| IaC | Terraform (modular) | Required by assignment, modules for network/compute/storage/IAM/logging |
| CI/CD | GitLab CI | Required by assignment, plan artifact + manual deploy |

## Architecture

```
Client → API Gateway (HTTP API) → Lambda (FastAPI + Mangum) → RDS PostgreSQL
                                       ↓
                                CloudWatch Logs

ECR (container registry) ← GitLab CI (build + push)
```

- API Gateway handles HTTPS termination and routing
- Lambda runs in VPC private subnets to access RDS
- RDS in private subnets, no public accessibility
- Lambda logs automatically to CloudWatch (independent of VPC config)
- API Gateway access logs to a separate CloudWatch log group

## Application Design

### CRUD Resource: Note

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key, auto-generated |
| `title` | string | Required |
| `body` | text | Required |
| `created_at` | timestamp | Auto-set on creation |

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/notes` | Create a note |
| GET | `/notes` | List all notes |
| GET | `/notes/{id}` | Get one note |
| PUT | `/notes/{id}` | Update a note |
| DELETE | `/notes/{id}` | Delete a note |
| GET | `/health` | Health check |

### Application Stack

- FastAPI + Mangum (ASGI → Lambda adapter)
- SQLAlchemy ORM + psycopg2 (sync driver, simpler on Lambda)
- Alembic for database migrations
- Pydantic for request/response validation
- Base image: `public.ecr.aws/lambda/python:3.11`

### Application Structure

```
app/
  main.py              (FastAPI app + Mangum handler)
  models.py            (SQLAlchemy model)
  schemas.py           (Pydantic schemas)
  database.py          (DB connection setup)
  config.py            (env-based settings)
  alembic/             (migrations)
  Dockerfile
  requirements.txt
```

### Configuration

Environment variables set via Terraform Lambda config:
- `DATABASE_URL` — PostgreSQL connection string
- `LOG_LEVEL` — logging verbosity (default: INFO)

## Terraform Infrastructure

### Module Structure

```
terraform/
  modules/
    network/       (VPC, subnets, security groups)
    compute/       (Lambda, API Gateway, ECR)
    storage/       (RDS PostgreSQL, subnet group)
    iam/           (Lambda execution role, policies)
    logging/       (CloudWatch log groups, retention)
  environments/
    dev/           (main.tf, variables.tf, outputs.tf, backend.tf)
```

### Network Module

- 1 VPC (CIDR: `10.0.0.0/16`)
- 2 private subnets across 2 AZs (required for RDS subnet group)
- No public subnets (API Gateway is AWS-managed, Lambda only needs internal RDS access)
- Security groups:
  - Lambda SG: outbound to RDS SG on port 5432
  - RDS SG: inbound from Lambda SG on port 5432 only

### Compute Module

- ECR repository for the application container image
- Lambda function:
  - Package type: container image (from ECR)
  - VPC-attached (private subnets)
  - Memory: 256 MB (adjustable via variable)
  - Timeout: 30s
- API Gateway (HTTP API type):
  - Default stage with auto-deploy
  - Lambda proxy integration
  - Routes: `ANY /{proxy+}` (catch-all to FastAPI router)

### Storage Module

- RDS PostgreSQL instance:
  - Engine: PostgreSQL 15
  - Instance class: db.t3.micro
  - Single-AZ (cost-safe)
  - Storage: 20 GB gp3, encrypted at rest (default AWS KMS key)
  - No public accessibility
  - DB subnet group spanning 2 private subnets
  - Deletion protection: off (demo purposes, documented)
  - Skip final snapshot: true (demo purposes)

### IAM Module

- Lambda execution role with policies:
  - `AWSLambdaVPCAccessExecutionRole` (create/delete ENIs for VPC)
  - CloudWatch Logs: `logs:CreateLogStream`, `logs:PutLogEvents` on function log group
  - ECR: `ecr:GetDownloadBundle`, `ecr:BatchGetImage` on the app repo
- No broad `*` resource policies — all scoped to specific ARNs

### Logging Module

- CloudWatch log group: `/aws/lambda/<function-name>` (retention: 30 days)
- CloudWatch log group: `/aws/apigateway/<api-name>` (retention: 30 days)
- RDS CloudWatch logs export: PostgreSQL error logs (retention: 30 days)

### State Management

- `backend.tf` contains S3 + DynamoDB backend config (commented out with setup instructions)
- Default: local state for easy evaluator testing
- README documents how to enable remote state

### Variables

| Variable | Type | Description |
|----------|------|-------------|
| `aws_region` | string | Target AWS region (default: eu-west-1) |
| `environment` | string | Environment name (default: dev) |
| `db_password` | string (sensitive) | RDS master password |
| `app_image_tag` | string | Container image tag (default: latest) |

### Outputs

| Output | Description |
|--------|-------------|
| `api_url` | API Gateway invoke URL |
| `rds_endpoint` | RDS instance endpoint |
| `ecr_repo_url` | ECR repository URL |

## Logging & Observability

| Log Source | Destination | Retention |
|------------|-------------|-----------|
| Application (FastAPI via stdout) | CloudWatch `/aws/lambda/<name>` | 30 days |
| API Gateway access logs | CloudWatch `/aws/apigateway/<name>` | 30 days |
| RDS PostgreSQL error logs | CloudWatch `/aws/rds/<name>` | 30 days |

Application logs are structured JSON (via Python `logging` with JSON formatter).

## CI/CD Pipeline (GitLab CI)

### Stages

1. **validate** — `terraform fmt -check`, `terraform validate`, Python linting
2. **build** — Build Docker image, push to ECR (tag = commit SHA)
3. **plan** — `terraform plan -out=tfplan` → saved as pipeline artifact
4. **deploy** — `terraform apply tfplan` (manual trigger, `when: manual`)

### Key Design Decisions

- Plan artifact attached for review before manual deploy
- No automatic apply on merge
- Docker image tagged with commit SHA for traceability
- Build and plan run on every push; deploy is manual only

### Required CI Variables

| Variable | Purpose |
|----------|---------|
| `AWS_ACCESS_KEY_ID` | AWS authentication for Terraform + ECR push |
| `AWS_SECRET_ACCESS_KEY` | AWS authentication |
| `AWS_DEFAULT_REGION` | Target AWS region |
| `TF_VAR_db_password` | RDS master password (passed as Terraform variable) |

## Repository Structure

```
/
  app/                    (FastAPI application source)
  terraform/              (Infrastructure as Code)
  .gitlab-ci.yml          (CI/CD pipeline)
  README.md               (Architecture, deployment, verification instructions)
```

## README Contents

1. Architecture overview with ASCII diagram
2. Technology choices with justifications
3. Prerequisites (Terraform, AWS CLI, Docker)
4. Local development instructions
5. Required CI variables table
6. Deployment steps (first-time setup + CI pipeline flow)
7. How to verify the system (curl examples against API GW URL)
8. Where to find logs (CloudWatch log group paths)
9. Remote state setup instructions
10. Cost considerations

## Security Posture

- **IAM:** Least privilege — Lambda role scoped to specific resources, no `*` policies
- **Network:** RDS in private subnets, no public access, SG allows only Lambda on port 5432
- **Encryption:** RDS storage encrypted at rest (AWS KMS default key)
- **Secrets:** DB password via CI variable (`TF_VAR_db_password`), never in code
- **No hardcoded ARNs/credentials** in Terraform — all parameterised
