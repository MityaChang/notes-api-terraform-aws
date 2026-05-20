# Notes API — Full-Stack + Terraform on AWS

A production-ready CRUD REST API for managing notes, deployed on AWS using serverless compute (Lambda + API Gateway), backed by RDS PostgreSQL, and provisioned entirely via modular Terraform.

## Architecture

```
Client → API Gateway (HTTP API) → Lambda (FastAPI + Mangum) → RDS PostgreSQL
              ↓                        ↓
       Access Logs              Application Logs
              ↓                        ↓
                    CloudWatch Logs (30-day retention)

ECR (container registry) ← GitLab CI (build + push)
```

## Technology Choices

| Component | Choice | Why |
|-----------|--------|-----|
| Language | Python 3.11 + FastAPI | Lightweight, excellent Lambda support via Mangum |
| Compute | Lambda + API Gateway (HTTP API) | Serverless, pay-per-request, zero idle cost |
| Database | RDS PostgreSQL (db.t3.micro) | Relational, encrypted at rest, free-tier eligible |
| Deployment | Container image → ECR → Lambda | Reproducible builds, satisfies container artifact requirement |
| IaC | Terraform (modular) | Separate modules for network, compute, storage, IAM, logging |
| CI/CD | GitLab CI | Plan artifact + manual deploy, no auto-apply |

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [Docker](https://www.docker.com/) for building container images
- Python 3.11+ (for local development)

## Project Structure

```
app/                     FastAPI application source
terraform/
  modules/
    network/             VPC, subnets, security groups
    compute/             Lambda, API Gateway
    storage/             RDS PostgreSQL
    iam/                 Lambda execution role and policies
    logging/             CloudWatch log groups
  environments/
    dev/                 Root module for dev environment (includes ECR)
.gitlab-ci.yml           CI/CD pipeline
README.md                This file
```

## Local Development

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

### First-Time Setup

1. **Deploy infrastructure (creates ECR + all resources):**
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform apply
   ```

2. **Build and push initial image:**
   ```bash
   ECR_URL=$(terraform output -raw ecr_repo_url)
   aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ECR_URL
   cd ../../../app
   docker build -t $ECR_URL:latest .
   docker push $ECR_URL:latest
   ```

3. **Update Lambda to use the image:**
   ```bash
   cd ../terraform/environments/dev
   terraform apply
   ```

4. **Run database migration:**
   ```bash
   # Via a Lambda invocation or local connection through a bastion:
   alembic upgrade head
   ```

### CI/CD Pipeline

The GitLab CI pipeline runs automatically on push to the default branch:

1. **validate** — `terraform fmt`, `terraform validate`, Python linting (ruff)
2. **build** — Builds Docker image, pushes to ECR (tagged with commit SHA)
3. **plan** — Generates `terraform plan` artifact for review
4. **deploy** — Manual trigger to apply the plan

## Required CI Variables

Configure these in GitLab → Settings → CI/CD → Variables:

| Variable | Type | Description |
|----------|------|-------------|
| `AWS_ACCESS_KEY_ID` | Variable | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | Variable (masked) | AWS IAM secret key |
| `AWS_DEFAULT_REGION` | Variable | Target region (e.g., `eu-west-1`) |
| `TF_VAR_db_password` | Variable (masked) | RDS master password |
| `ECR_REPO_URL` | Variable | ECR repository URL (from Terraform output) |

## Verifying the System

After deployment, get the API URL:
```bash
cd terraform/environments/dev
API_URL=$(terraform output -raw api_url)
```

Test the endpoints:
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

| Log Type | Location |
|----------|----------|
| Application logs | CloudWatch → `/aws/lambda/dev-notes-api` |
| API Gateway access logs | CloudWatch → `/aws/apigateway/dev-notes-api` |
| RDS PostgreSQL logs | CloudWatch → `/aws/rds/instance/dev-notes-db/postgresql` |

All log groups have a **30-day retention** period.

## Remote State Setup

By default, Terraform uses local state. For team/production use:

1. Create an S3 bucket with versioning enabled
2. Create a DynamoDB table with partition key `LockID` (String type)
3. Edit `terraform/environments/dev/backend.tf` — uncomment the S3 backend block
4. Run `terraform init -migrate-state`

## Security

- **IAM:** Lambda role follows least privilege (scoped to specific resource ARNs)
- **Network:** RDS in private subnets, no public access, SG allows only Lambda on port 5432
- **Encryption:** RDS storage encrypted at rest (AWS-managed KMS key)
- **Secrets:** DB password passed via CI variable, never committed to code
- **No hardcoded credentials** in Terraform or application code

## Cost Considerations

- **Lambda:** Free tier includes 1M requests/month — effectively free at low traffic
- **API Gateway:** $1.00 per million requests
- **RDS db.t3.micro:** Free-tier eligible (750 hrs/month for 12 months), ~$12/month after
- **ECR:** 500 MB free storage, minimal cost for single image
- **CloudWatch Logs:** First 5 GB ingestion/month free

**Estimated monthly cost at low traffic:** $0–15 (mostly RDS after free tier)
