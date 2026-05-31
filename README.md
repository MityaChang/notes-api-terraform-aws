# Notes API — Full-Stack + Terraform on AWS

A production-ready CRUD REST API for managing notes, deployed on AWS using serverless compute (Lambda + API Gateway), backed by RDS PostgreSQL, and provisioned entirely via modular Terraform.

## Table of Contents

- [Solution Overview](#solution-overview)
- [Infrastructure](#infrastructure)
  - [Infrastructure Architecture](#infrastructure-architecture)
  - [CI/CD Architecture](#cicd-architecture)
- [Technology Choices](#technology-choices)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Usage](#usage)
  - [Local Development](#local-development)
  - [Deployment](#deployment)
  - [CI/CD Pipeline](#cicd-pipeline)
- [Multi-Environment Support](#multi-environment-support)
- [Required CI Variables](#required-ci-variables)
- [Verifying the System](#verifying-the-system)
- [Where to Find Logs](#where-to-find-logs)
- [Security](#security)
- [Cost Considerations](#cost-considerations)
- [Cleanup](#cleanup)

---

## Solution Overview

This repository demonstrates a full-stack serverless application on AWS, provisioned with modular Terraform and deployed through a GitLab CI pipeline. It implements a single CRUD resource (notes) with attention to security, observability, and infrastructure best practices.

---

## Infrastructure

### Infrastructure Architecture

<p align="center">
  <img src="resources/infra_diagram.png" alt="Infrastructure Architecture" />
</p>

**AWS Resources provisioned:**

- 1 VPC with 2 private subnets (multi-AZ)
- 1 ECR repository (container image registry)
- 1 Lambda function (containerized FastAPI)
- 1 API Gateway HTTP API (public-facing)
- 1 RDS PostgreSQL instance (encrypted, private)
- 3 CloudWatch Log Groups (Lambda, API Gateway, RDS)
- 2 Security Groups (Lambda egress, RDS ingress)
- IAM roles and policies (least privilege)

### CI/CD Architecture

<p align="center">
  <img src="resources/cicd_diagram.png" alt="CI/CD Architecture" />
</p>

## Technology Choices

| Component  | Choice                          | Justification                                                 |
| ---------- | ------------------------------- | ------------------------------------------------------------- |
| Language   | Python 3.11 + FastAPI           | Lightweight, excellent Lambda support via Mangum adapter      |
| Compute    | Lambda + API Gateway (HTTP API) | Serverless, pay-per-request, zero idle cost                   |
| Database   | RDS PostgreSQL (db.t3.micro)    | Relational, encrypted at rest, free-tier eligible             |
| Deployment | Container image → ECR → Lambda  | Reproducible builds, satisfies container artifact requirement |
| IaC        | Terraform (modular)             | Separate modules for network, compute, storage, IAM, logging  |
| CI/CD      | GitLab CI + OIDC                | Plan artifact + manual deploy, no long-lived AWS keys         |
| Security   | Checkov + Bandit + Trivy        | IaC, SAST, and container vulnerability scanning               |

---

## Prerequisites

| Tool                                            | Version | Purpose                     |
| ----------------------------------------------- | ------- | --------------------------- |
| [Terraform](https://www.terraform.io/downloads) | >= 1.5  | Infrastructure provisioning |
| [AWS CLI](https://aws.amazon.com/cli/)          | v2      | AWS credential management   |
| [Docker](https://www.docker.com/)               | 24+     | Container image builds      |
| [Python](https://www.python.org/)               | 3.11+   | Local development           |

---

## Project Structure

```
├── app/                            FastAPI application source
│   ├── main.py                     API endpoints + Lambda handler
│   ├── models.py                   SQLAlchemy ORM models
│   ├── schemas.py                  Pydantic request/response schemas
│   ├── config.py                   Environment-based configuration
│   ├── database.py                 Database engine + session management
│   ├── Dockerfile                  Lambda container image definition
│   ├── requirements.txt            Python dependencies
│   └── alembic/                    Database migrations
├── terraform/
│   ├── modules/
│   │   ├── network/                VPC, subnets, security groups
│   │   ├── compute/                Lambda, API Gateway
│   │   ├── storage/                RDS PostgreSQL
│   │   ├── iam/                    Lambda execution role and policies
│   │   └── logging/                CloudWatch log groups
│   └── environments/
│       ├── dev/                    Development environment (active)
│       ├── stg/                    Staging environment (template)
│       └── prod/                   Production environment (template)
├── .gitlab-ci.yml                  CI/CD pipeline definition
├── .trivyignore                    Container scan exclusions
└── README.md                       This file
```

---

## Usage

### Local Development

```bash
cd app
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run locally (requires a PostgreSQL instance)
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/notes"
uvicorn app.main:app --reload --port 8000
```

## Deployment

### Prerequisites for Remote State

The default backend configuration uses S3 + DynamoDB for remote state and locking. This requires:

- An S3 bucket (`notes-api-tf-state-ap-southeast-1`) with versioning enabled
- A DynamoDB table (`terraform-state-lock`) with a `LockID` partition key
- IAM permissions for your user to access both resources

**For Testing locally:** If you don't have access to the remote state backend, switch to local state by editing `terraform/environments/dev/backend.tf`:

```hcl
# Comment out the S3 backend and uncomment local:
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

### First-Time Setup

On a clean AWS environment, there is a bootstrap dependency: the CI build stage needs ECR to push images, and Lambda needs an image to exist. This is resolved with a phased first deployment:

1. **Create ECR repository first:**

   ```bash
   # From the repository root:
   cd terraform/environments/dev
   terraform init
   terraform apply -target=aws_ecr_repository.app
   ```

2. **Build and push initial image:**

   ```bash
   ECR_URL=$(terraform output -raw ecr_repo_url)
   aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin $ECR_URL
   cd ../../../app
   docker build -t $ECR_URL:latest .
   docker push $ECR_URL:latest
   ```

3. **Deploy all remaining infrastructure:**

   ```bash
   cd ../terraform/environments/dev
   terraform apply
   ```

4. **Run database migration:**
   ```bash
   # Via a Lambda invocation or local connection through a bastion:
   alembic upgrade head
   ```

> **Note:** After first time setupp, the CI/CD pipeline handles this automatically — the build stage pushes the image before the deploy stage runs `terraform apply`.

### CI/CD Pipeline

The GitLab CI pipeline runs automatically on push:

| Stage        | Jobs                                                                                          | Purpose                                  |
| ------------ | --------------------------------------------------------------------------------------------- | ---------------------------------------- |
| **validate** | `terraform-fmt`, `terraform-validate`, `python-lint`, `python-security`, `terraform-security` | Code quality + security scanning         |
| **build**    | `build-image`, `container-security`                                                           | Build container, push to ECR, Trivy scan |
| **plan**     | `terraform-plan`                                                                              | Generate plan artifact for review        |
| **deploy**   | `terraform-apply`                                                                             | **Manual trigger** to apply changes      |

> **Note:** The deploy stage requires manual approval — no automatic applies on merge.

---

## Multi-Environment Support

The `terraform/environments/` directory supports multiple isolated environments sharing the same modules:

```
terraform/environments/
├── dev/        ← Active (fully configured)
├── stg/        ← Template (copy from dev, adjust variables)
└── prod/       ← Template (copy from dev, harden settings)
```

Each environment has:

- Its own Terraform state file (independent apply/destroy)
- Its own variable values (instance sizes, retention, feature flags)
- Its own CI/CD pipeline stage or branch rules

See the README in each environment folder for specific instructions on what to modify.

---

## Required CI Variables

Configure these in **GitLab → Settings → CI/CD → Variables**:

| Variable             | Type     | Protected | Masked | Description                                           |
| -------------------- | -------- | --------- | ------ | ----------------------------------------------------- |
| `PROVIDER`           | Variable | ✓         |        | IAM role ARN for OIDC-based AWS credential assumption |
| `AWS_ACCOUNT_ID`     | Variable | ✓         |        | AWS account ID (e.g., `760638704957`)                 |
| `ECR_REPO_NAME`      | Variable |           |        | ECR repository name (e.g., `dev-notes-api`)           |
| `TF_VAR_db_password` | Variable | ✓         | ✓      | RDS master password                                   |

---

## Verifying the System

After deployment, get the API URL:

```bash
cd terraform/environments/dev
API_URL=$(terraform output -raw api_url)
```

**Interactive API docs (fastest way to verify):**

Open `$API_URL/docs` in your browser — Swagger UI lets you test all CRUD operations interactively without curl.

Test the endpoints via CLI:

```bash
# Health check
curl $API_URL/health

# Create a note
curl -X POST $API_URL/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "Hello", "body": "World"}'

# List notes
curl $API_URL/notes

# Get a specific note
curl $API_URL/notes/<note-id>

# Update a note
curl -X PUT $API_URL/notes/<note-id> \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated Title"}'

# Delete a note
curl -X DELETE $API_URL/notes/<note-id>
```

## Where to Find Logs

| Log Type                | CloudWatch Path                             | Retention |
| ----------------------- | ------------------------------------------- | --------- |
| Application logs        | `/aws/lambda/dev-notes-api`                 | 30 days   |
| API Gateway access logs | `/aws/apigateway/dev-notes-api`             | 30 days   |
| RDS PostgreSQL logs     | `/aws/rds/instance/dev-notes-db/postgresql` | 30 days   |

---

## Security

| Layer           | Implementation                                                               |
| --------------- | ---------------------------------------------------------------------------- |
| **IAM**         | Lambda role follows least privilege — scoped to specific resource ARNs       |
| **Network**     | RDS in private subnets, no public access, SG allows only Lambda on port 5432 |
| **Encryption**  | RDS storage encrypted at rest (AWS-managed KMS key)                          |
| **Secrets**     | DB password passed via masked CI variable, never committed to code           |
| **Scanning**    | Checkov (IaC), Bandit (Python SAST), pip-audit (CVEs), Trivy (container)     |
| **Credentials** | OIDC-based — no long-lived AWS access keys                                   |

---

## Cost Considerations

| Service         | Free Tier                 | After Free Tier       |
| --------------- | ------------------------- | --------------------- |
| Lambda          | 1M requests/month         | $0.20 per 1M requests |
| API Gateway     | 1M requests/month         | $1.00 per 1M requests |
| RDS db.t3.micro | 750 hrs/month (12 months) | ~$12/month            |
| ECR             | 500 MB storage            | ~$0.10/GB/month       |
| CloudWatch Logs | 5 GB ingestion/month      | $0.50/GB              |

**Estimated monthly cost at low traffic:** $0–15 (mostly RDS after free tier expires)

---

## Cleanup

To destroy all infrastructure resources:

```bash
cd terraform/environments/dev
terraform destroy
```

> **Warning:** This will delete all resources including the RDS database and its data. Ensure you have backups if needed.

---

## License

This project is provided as-is for demonstration and assessment purposes.
