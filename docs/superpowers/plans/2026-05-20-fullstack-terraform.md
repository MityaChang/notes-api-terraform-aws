# Full-Stack REST API + Terraform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a production-ready Notes CRUD API on AWS Lambda + API Gateway + RDS PostgreSQL, provisioned via modular Terraform, with GitLab CI pipeline.

**Architecture:** FastAPI app wrapped with Mangum runs on Lambda (container image from ECR). API Gateway HTTP API handles routing/TLS. RDS PostgreSQL in VPC private subnets stores data. Lambda in same VPC subnets accesses RDS directly. CloudWatch for all logging.

**Tech Stack:** Python 3.11, FastAPI, Mangum, SQLAlchemy, psycopg2, Alembic, Terraform 1.5+, Docker, GitLab CI

---

## File Structure

```
app/
  main.py                  # FastAPI app, routes, Mangum handler
  models.py                # SQLAlchemy Note model
  schemas.py               # Pydantic request/response schemas
  database.py              # DB engine and session setup
  config.py                # Environment-based settings
  requirements.txt         # Python dependencies
  Dockerfile               # Lambda container image
  alembic.ini              # Alembic config
  alembic/
    env.py                 # Alembic environment
    versions/
      001_create_notes.py  # Initial migration

terraform/
  modules/
    network/
      main.tf              # VPC, subnets, security groups
      variables.tf
      outputs.tf
    compute/
      main.tf              # Lambda, API Gateway, ECR
      variables.tf
      outputs.tf
    storage/
      main.tf              # RDS instance, subnet group
      variables.tf
      outputs.tf
    iam/
      main.tf              # Lambda role and policies
      variables.tf
      outputs.tf
    logging/
      main.tf              # CloudWatch log groups
      variables.tf
      outputs.tf
  environments/
    dev/
      main.tf              # Root module, calls all modules
      variables.tf         # Input variables with defaults
      outputs.tf           # Exposed outputs
      backend.tf           # State config (commented S3 + local default)
      terraform.tfvars     # Non-sensitive defaults (gitignored template)

.gitlab-ci.yml             # CI/CD pipeline
README.md                  # Documentation
.gitignore                 # Ignore .terraform, *.tfstate, __pycache__, etc.
```

---

## Task 1: Project Scaffolding & Git Setup

**Files:**

- Create: `.gitignore`
- Create: `README.md` (placeholder, filled in Task 10)

- [ ] **Step 1: Initialize git repo and create .gitignore**

```bash
cd /Users/necmsbu/Projects/simple-fullstack-terraform
git init
```

Create `.gitignore`:

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfplan
.terraform.lock.hcl

# Python
__pycache__/
*.pyc
*.pyo
.venv/
venv/
*.egg-info/

# Environment
.env
*.env

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db
```

- [ ] **Step 2: Create placeholder README**

Create `README.md`:

```markdown
# Notes API — Full-Stack + Terraform on AWS

Documentation will be completed after implementation.
```

- [ ] **Step 3: Create directory structure**

```bash
mkdir -p app/alembic/versions
mkdir -p terraform/modules/{network,compute,storage,iam,logging}
mkdir -p terraform/environments/dev
```

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "chore: initial project scaffolding"
```

---

## Task 2: Application — Config, Database, Models

**Files:**

- Create: `app/config.py`
- Create: `app/database.py`
- Create: `app/models.py`
- Create: `app/requirements.txt`

- [ ] **Step 1: Create requirements.txt**

Create `app/requirements.txt`:

```
fastapi==0.104.1
mangum==0.17.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
pydantic==2.5.2
pydantic-settings==2.1.0
alembic==1.13.0
python-json-logger==2.0.7
uvicorn==0.24.0
```

- [ ] **Step 2: Create config.py**

Create `app/config.py`:

```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://postgres:postgres@localhost:5432/notes"
    log_level: str = "INFO"

    class Config:
        env_file = ".env"


settings = Settings()
```

- [ ] **Step 3: Create database.py**

Create `app/database.py`:

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from app.config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True, pool_size=5)
SessionLocal = sessionmaker(bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

- [ ] **Step 4: Create models.py**

Create `app/models.py`:

```python
import uuid
from datetime import datetime, timezone

from sqlalchemy import String, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Note(Base):
    __tablename__ = "notes"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
```

- [ ] **Step 5: Commit**

```bash
git add app/
git commit -m "feat(app): add config, database, and Note model"
```

---

## Task 3: Application — Pydantic Schemas

**Files:**

- Create: `app/schemas.py`

- [ ] **Step 1: Create schemas.py**

Create `app/schemas.py`:

```python
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class NoteCreate(BaseModel):
    title: str
    body: str


class NoteUpdate(BaseModel):
    title: str | None = None
    body: str | None = None


class NoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    body: str
    created_at: datetime
```

- [ ] **Step 2: Commit**

```bash
git add app/schemas.py
git commit -m "feat(app): add Pydantic schemas for Note"
```

---

## Task 4: Application — FastAPI Routes & Mangum Handler

**Files:**

- Create: `app/main.py`

- [ ] **Step 1: Create main.py**

Create `app/main.py`:

```python
import logging
import sys

from fastapi import FastAPI, HTTPException, Depends
from mangum import Mangum
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import Note
from app.schemas import NoteCreate, NoteUpdate, NoteResponse

# Structured JSON logging
from pythonjsonlogger import jsonlogger

logger = logging.getLogger()
handler = logging.StreamHandler(sys.stdout)
formatter = jsonlogger.JsonFormatter(
    fmt="%(asctime)s %(levelname)s %(name)s %(message)s"
)
handler.setFormatter(formatter)
logger.handlers = [handler]
logger.setLevel(settings.log_level)

app = FastAPI(title="Notes API", version="1.0.0")


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.post("/notes", response_model=NoteResponse, status_code=201)
def create_note(note: NoteCreate, db: Session = Depends(get_db)):
    db_note = Note(title=note.title, body=note.body)
    db.add(db_note)
    db.commit()
    db.refresh(db_note)
    logger.info("Note created", extra={"note_id": db_note.id})
    return db_note


@app.get("/notes", response_model=list[NoteResponse])
def list_notes(db: Session = Depends(get_db)):
    return db.query(Note).order_by(Note.created_at.desc()).all()


@app.get("/notes/{note_id}", response_model=NoteResponse)
def get_note(note_id: str, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@app.put("/notes/{note_id}", response_model=NoteResponse)
def update_note(note_id: str, note_update: NoteUpdate, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    if note_update.title is not None:
        note.title = note_update.title
    if note_update.body is not None:
        note.body = note_update.body
    db.commit()
    db.refresh(note)
    logger.info("Note updated", extra={"note_id": note.id})
    return note


@app.delete("/notes/{note_id}", status_code=204)
def delete_note(note_id: str, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    db.delete(note)
    db.commit()
    logger.info("Note deleted", extra={"note_id": note_id})


# Lambda handler
handler = Mangum(app, lifespan="off")
```

- [ ] **Step 2: Commit**

```bash
git add app/main.py
git commit -m "feat(app): add FastAPI routes and Mangum Lambda handler"
```

---

## Task 5: Application — Alembic Migrations & Dockerfile

**Files:**

- Create: `app/alembic.ini`
- Create: `app/alembic/env.py`
- Create: `app/alembic/versions/001_create_notes.py`
- Create: `app/Dockerfile`

- [ ] **Step 1: Create alembic.ini**

Create `app/alembic.ini`:

```ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql://postgres:postgres@localhost:5432/notes

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
```

- [ ] **Step 2: Create alembic/env.py**

Create `app/alembic/env.py`:

```python
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.database import Base
from app.models import Note  # noqa: F401 - registers model with Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

- [ ] **Step 3: Create initial migration**

Create `app/alembic/versions/001_create_notes.py`:

```python
"""create notes table

Revision ID: 001
Revises:
Create Date: 2026-05-20
"""

from alembic import op
import sqlalchemy as sa

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "notes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False,
            server_default=sa.func.now()
        ),
    )


def downgrade():
    op.drop_table("notes")
```

- [ ] **Step 4: Create Dockerfile**

Create `app/Dockerfile`:

```dockerfile
FROM public.ecr.aws/lambda/python:3.11

COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

COPY . ${LAMBDA_TASK_ROOT}/

CMD ["app.main.handler"]
```

- [ ] **Step 5: Commit**

```bash
git add app/
git commit -m "feat(app): add Alembic migrations and Lambda Dockerfile"
```

---

## Task 6: Terraform — Network Module

**Files:**

- Create: `terraform/modules/network/main.tf`
- Create: `terraform/modules/network/variables.tf`
- Create: `terraform/modules/network/outputs.tf`

- [ ] **Step 1: Create network/variables.tf**

Create `terraform/modules/network/variables.tf`:

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
```

- [ ] **Step 2: Create network/main.tf**

Create `terraform/modules/network/main.tf`:

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.environment}-private-${count.index}"
    Environment = var.environment
  }
}

resource "aws_security_group" "lambda" {
  name_prefix = "${var.environment}-lambda-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Lambda function"

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow outbound to RDS"
  }

  tags = {
    Name        = "${var.environment}-lambda-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-rds-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for RDS instance"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "Allow inbound from Lambda"
  }

  tags = {
    Name        = "${var.environment}-rds-sg"
    Environment = var.environment
  }
}
```

- [ ] **Step 3: Create network/outputs.tf**

Create `terraform/modules/network/outputs.tf`:

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
```

- [ ] **Step 4: Commit**

```bash
git add terraform/modules/network/
git commit -m "feat(infra): add network module — VPC, subnets, security groups"
```

---

## Task 7: Terraform — IAM Module

**Files:**

- Create: `terraform/modules/iam/main.tf`
- Create: `terraform/modules/iam/variables.tf`
- Create: `terraform/modules/iam/outputs.tf`

- [ ] **Step 1: Create iam/variables.tf**

Create `terraform/modules/iam/variables.tf`:

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "ecr_repo_arn" {
  description = "ECR repository ARN"
  type        = string
}

variable "log_group_arn" {
  description = "CloudWatch log group ARN for Lambda"
  type        = string
}
```

- [ ] **Step 2: Create iam/main.tf**

Create `terraform/modules/iam/main.tf`:

```hcl
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.environment}-${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  # VPC access (create/delete ENIs)
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${var.log_group_arn}:*"]
  }

  # ECR pull
  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [var.ecr_repo_arn]
  }

  # ECR auth token (required for image pull, must be *)
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.environment}-${var.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}
```

- [ ] **Step 3: Create iam/outputs.tf**

Create `terraform/modules/iam/outputs.tf`:

```hcl
output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}
```

- [ ] **Step 4: Commit**

```bash
git add terraform/modules/iam/
git commit -m "feat(infra): add IAM module — Lambda role with least privilege"
```

---

## Task 8: Terraform — Logging Module

**Files:**

- Create: `terraform/modules/logging/main.tf`
- Create: `terraform/modules/logging/variables.tf`
- Create: `terraform/modules/logging/outputs.tf`

- [ ] **Step 1: Create logging/variables.tf**

Create `terraform/modules/logging/variables.tf`:

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "api_name" {
  description = "API Gateway name"
  type        = string
}

variable "retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}
```

- [ ] **Step 2: Create logging/main.tf**

Create `terraform/modules/logging/main.tf`:

```hcl
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.environment}-${var.function_name}"
  retention_in_days = var.retention_days

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.environment}-${var.api_name}"
  retention_in_days = var.retention_days

  tags = {
    Environment = var.environment
  }
}
```

- [ ] **Step 3: Create logging/outputs.tf**

Create `terraform/modules/logging/outputs.tf`:

```hcl
output "lambda_log_group_arn" {
  value = aws_cloudwatch_log_group.lambda.arn
}

output "lambda_log_group_name" {
  value = aws_cloudwatch_log_group.lambda.name
}

output "api_gateway_log_group_arn" {
  value = aws_cloudwatch_log_group.api_gateway.arn
}
```

- [ ] **Step 4: Commit**

```bash
git add terraform/modules/logging/
git commit -m "feat(infra): add logging module — CloudWatch log groups with retention"
```

---

## Task 9: Terraform — Storage Module

**Files:**

- Create: `terraform/modules/storage/main.tf`
- Create: `terraform/modules/storage/variables.tf`
- Create: `terraform/modules/storage/outputs.tf`

- [ ] **Step 1: Create storage/variables.tf**

Create `terraform/modules/storage/variables.tf`:

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "notes"
}

variable "db_username" {
  description = "Master username"
  type        = string
  default     = "notesadmin"
}
```

- [ ] **Step 2: Create storage/main.tf**

Create `terraform/modules/storage/main.tf`:

```hcl
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.environment}-notes-db"

  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = false

  enabled_cloudwatch_logs_exports = ["postgresql"]

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.environment}-notes-db"
    Environment = var.environment
  }
}
```

- [ ] **Step 3: Create storage/outputs.tf**

Create `terraform/modules/storage/outputs.tf`:

```hcl
output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_username" {
  value = aws_db_instance.main.username
}

output "db_connection_string" {
  value     = "postgresql://${aws_db_instance.main.username}:${var.db_password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive = true
}
```

- [ ] **Step 4: Commit**

```bash
git add terraform/modules/storage/
git commit -m "feat(infra): add storage module — RDS PostgreSQL with encryption"
```

---

## Task 10: Terraform — Compute Module

**Files:**

- Create: `terraform/modules/compute/main.tf`
- Create: `terraform/modules/compute/variables.tf`
- Create: `terraform/modules/compute/outputs.tf`

- [ ] **Step 1: Create compute/variables.tf**

Create `terraform/modules/compute/variables.tf`:

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "notes-api"
}

variable "lambda_role_arn" {
  description = "IAM role ARN for Lambda"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda VPC config"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Lambda"
  type        = string
}

variable "image_tag" {
  description = "Container image tag"
  type        = string
  default     = "latest"
}

variable "database_url" {
  description = "Database connection string"
  type        = string
  sensitive   = true
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
}

variable "lambda_log_group_name" {
  description = "CloudWatch log group name for Lambda"
  type        = string
}

variable "api_gateway_log_group_arn" {
  description = "CloudWatch log group ARN for API Gateway"
  type        = string
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}
```

- [ ] **Step 2: Create compute/main.tf**

Create `terraform/modules/compute/main.tf`:

```hcl
# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "${var.environment}-${var.function_name}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
  }
}

# Lambda Function
resource "aws_lambda_function" "api" {
  function_name = "${var.environment}-${var.function_name}"
  role          = var.lambda_role_arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
  timeout       = var.timeout
  memory_size   = var.memory_size

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      DATABASE_URL = var.database_url
      LOG_LEVEL    = var.log_level
    }
  }

  depends_on = [aws_ecr_repository.app]

  tags = {
    Environment = var.environment
  }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.environment}-${var.function_name}"
  protocol_type = "HTTP"

  tags = {
    Environment = var.environment
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = var.api_gateway_log_group_arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
```

- [ ] **Step 3: Create compute/outputs.tf**

Create `terraform/modules/compute/outputs.tf`:

```hcl
output "api_url" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecr_repo_arn" {
  value = aws_ecr_repository.app.arn
}

output "function_name" {
  value = aws_lambda_function.api.function_name
}
```

- [ ] **Step 4: Commit**

```bash
git add terraform/modules/compute/
git commit -m "feat(infra): add compute module — Lambda, API Gateway, ECR"
```

---

## Task 11: Terraform — Environment Root Module

**Files:**

- Create: `terraform/environments/dev/main.tf`
- Create: `terraform/environments/dev/variables.tf`
- Create: `terraform/environments/dev/outputs.tf`
- Create: `terraform/environments/dev/backend.tf`

- [ ] **Step 1: Create variables.tf**

Create `terraform/environments/dev/variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "app_image_tag" {
  description = "Container image tag for Lambda"
  type        = string
  default     = "latest"
}
```

- [ ] **Step 2: Create backend.tf**

Create `terraform/environments/dev/backend.tf`:

```hcl
# Remote state configuration (recommended for team use)
# Uncomment and configure the following block:
#
# terraform {
#   backend "s3" {
#     bucket         = "your-project-terraform-state"
#     key            = "dev/terraform.tfstate"
#     region         = "eu-west-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
#
# To set up remote state:
# 1. Create an S3 bucket with versioning enabled
# 2. Create a DynamoDB table with partition key "LockID" (String)
# 3. Uncomment the block above and run `terraform init -migrate-state`

# Using local state by default for easy evaluator testing
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

- [ ] **Step 3: Create main.tf**

Create `terraform/environments/dev/main.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  function_name = "notes-api"
  api_name      = "notes-api"
}

module "logging" {
  source = "../../modules/logging"

  environment   = var.environment
  function_name = local.function_name
  api_name      = local.api_name
}

module "network" {
  source = "../../modules/network"

  environment = var.environment
  aws_region  = var.aws_region
}

module "iam" {
  source = "../../modules/iam"

  environment   = var.environment
  function_name = local.function_name
  ecr_repo_arn  = module.compute.ecr_repo_arn
  log_group_arn = module.logging.lambda_log_group_arn
}

module "storage" {
  source = "../../modules/storage"

  environment       = var.environment
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.rds_security_group_id
  db_password       = var.db_password
}

module "compute" {
  source = "../../modules/compute"

  environment               = var.environment
  lambda_role_arn           = module.iam.lambda_role_arn
  subnet_ids                = module.network.private_subnet_ids
  security_group_id         = module.network.lambda_security_group_id
  image_tag                 = var.app_image_tag
  database_url              = module.storage.db_connection_string
  lambda_log_group_name     = module.logging.lambda_log_group_name
  api_gateway_log_group_arn = module.logging.api_gateway_log_group_arn
}
```

- [ ] **Step 4: Create outputs.tf**

Create `terraform/environments/dev/outputs.tf`:

```hcl
output "api_url" {
  description = "API Gateway invoke URL"
  value       = module.compute.api_url
}

output "ecr_repo_url" {
  description = "ECR repository URL"
  value       = module.compute.ecr_repo_url
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.storage.db_endpoint
}
```

- [ ] **Step 5: Commit**

```bash
git add terraform/environments/
git commit -m "feat(infra): add dev environment root module"
```

---

## Task 12: GitLab CI Pipeline

**Files:**

- Create: `.gitlab-ci.yml`

- [ ] **Step 1: Create .gitlab-ci.yml**

Create `.gitlab-ci.yml`:

```yaml
stages:
  - validate
  - build
  - plan
  - deploy

variables:
  TF_DIR: terraform/environments/dev
  APP_DIR: app
  TF_IN_AUTOMATION: "true"

# --- Validate Stage ---

terraform-fmt:
  stage: validate
  image: hashicorp/terraform:1.5
  script:
    - cd $TF_DIR
    - terraform fmt -check -recursive ../..

terraform-validate:
  stage: validate
  image: hashicorp/terraform:1.5
  script:
    - cd $TF_DIR
    - terraform init -backend=false
    - terraform validate

python-lint:
  stage: validate
  image: python:3.11-slim
  script:
    - pip install ruff
    - cd $APP_DIR
    - ruff check .

# --- Build Stage ---

build-image:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  before_script:
    - apk add --no-cache aws-cli
    - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL
  script:
    - cd $APP_DIR
    - docker build -t $ECR_REPO_URL:$CI_COMMIT_SHORT_SHA .
    - docker push $ECR_REPO_URL:$CI_COMMIT_SHORT_SHA
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# --- Plan Stage ---

terraform-plan:
  stage: plan
  image: hashicorp/terraform:1.5
  script:
    - cd $TF_DIR
    - terraform init
    - terraform plan -var="app_image_tag=$CI_COMMIT_SHORT_SHA" -out=tfplan
  artifacts:
    paths:
      - $TF_DIR/tfplan
    expire_in: 7 days
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# --- Deploy Stage ---

terraform-apply:
  stage: deploy
  image: hashicorp/terraform:1.5
  script:
    - cd $TF_DIR
    - terraform init
    - terraform apply tfplan
  dependencies:
    - terraform-plan
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
```

- [ ] **Step 2: Commit**

```bash
git add .gitlab-ci.yml
git commit -m "feat(ci): add GitLab CI pipeline — validate, build, plan, manual deploy"
```

---

## Task 13: README Documentation

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Write complete README**

Replace `README.md` contents with:

```markdown
# Notes API — Full-Stack + Terraform on AWS

A production-ready CRUD REST API for managing notes, deployed on AWS using serverless compute (Lambda + API Gateway), backed by RDS PostgreSQL, and provisioned entirely via modular Terraform.

## Architecture
```

Client → API Gateway (HTTP API) → Lambda (FastAPI + Mangum) → RDS PostgreSQL
↓ ↓
Access Logs Application Logs
↓ ↓
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

app/ FastAPI application source
terraform/
modules/
network/ VPC, subnets, security groups
compute/ Lambda, API Gateway, ECR
storage/ RDS PostgreSQL
iam/ Lambda execution role and policies
logging/ CloudWatch log groups
environments/
dev/ Root module for dev environment
.gitlab-ci.yml CI/CD pipeline
README.md This file

````

## Local Development

```bash
cd app
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run locally (requires a PostgreSQL instance)
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/notes"
uvicorn app.main:app --reload --port 8000
````

## Deployment

### First-Time Setup

1. **Create ECR repository** (done by Terraform, but you need an initial image):

   ```bash
   cd terraform/environments/dev
   terraform init
   terraform apply -target=module.compute.aws_ecr_repository.app
   ```

2. **Build and push initial image:**

   ```bash
   ECR_URL=$(terraform output -raw ecr_repo_url)
   aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ECR_URL
   cd ../../../app
   docker build -t $ECR_URL:latest .
   docker push $ECR_URL:latest
   ```

3. **Deploy full infrastructure:**

   ```bash
   cd ../terraform/environments/dev
   terraform apply
   ```

4. **Run database migration:**
   ```bash
   # Connect to the RDS instance (via bastion or Lambda invocation) and run:
   alembic upgrade head
   ```

### CI/CD Pipeline

The GitLab CI pipeline runs automatically on push to the default branch:

1. **validate** — `terraform fmt`, `terraform validate`, Python linting
2. **build** — Builds Docker image, pushes to ECR (tagged with commit SHA)
3. **plan** — Generates `terraform plan` artifact for review
4. **deploy** — Manual trigger to apply the plan

## Required CI Variables

Configure these in GitLab → Settings → CI/CD → Variables:

| Variable                | Type              | Description                                |
| ----------------------- | ----------------- | ------------------------------------------ |
| `AWS_ACCESS_KEY_ID`     | Variable          | AWS IAM access key                         |
| `AWS_SECRET_ACCESS_KEY` | Variable (masked) | AWS IAM secret key                         |
| `AWS_DEFAULT_REGION`    | Variable          | Target region (e.g., `eu-west-1`)          |
| `TF_VAR_db_password`    | Variable (masked) | RDS master password                        |
| `ECR_REPO_URL`          | Variable          | ECR repository URL (from Terraform output) |

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

| Log Type                | Location                                                 |
| ----------------------- | -------------------------------------------------------- |
| Application logs        | CloudWatch → `/aws/lambda/dev-notes-api`                 |
| API Gateway access logs | CloudWatch → `/aws/apigateway/dev-notes-api`             |
| RDS PostgreSQL logs     | CloudWatch → `/aws/rds/instance/dev-notes-db/postgresql` |

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

````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add complete README with architecture and deployment guide"
````

---

## Task 14: Final Validation

- [ ] **Step 1: Run terraform fmt**

```bash
cd terraform/environments/dev
terraform fmt -recursive ../..
```

Fix any formatting issues.

- [ ] **Step 2: Run terraform validate**

```bash
terraform init -backend=false
terraform validate
```

Expected: "Success! The configuration is valid."

- [ ] **Step 3: Verify directory structure**

```bash
cd /Users/necmsbu/Projects/simple-fullstack-terraform
find . -type f | grep -v .git | grep -v __pycache__ | sort
```

Verify the structure matches the plan.

- [ ] **Step 4: Final commit (if formatting changes)**

```bash
git add -A
git status
# If changes exist:
git commit -m "style: terraform fmt"
```

---

## Circular Dependency Note

There is a circular reference in `main.tf`: the IAM module needs `module.compute.ecr_repo_arn`, but compute needs `module.iam.lambda_role_arn`.

**Resolution:** Move the ECR repository resource from the compute module into its own resource in `main.tf` (or create the ECR repo in the IAM module inputs as a data source). The simplest fix: define `aws_ecr_repository` directly in the root `main.tf` and pass its ARN to both modules.

This will be handled during implementation by defining the ECR repo in the root module and passing `ecr_repo_arn` to IAM and `ecr_repo_url` to compute.
