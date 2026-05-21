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

# ECR Repository (defined here to avoid circular dependency between IAM and compute)
#checkov:skip=CKV_AWS_136:AWS AES-256 default encryption sufficient for dev; KMS adds cost
resource "aws_ecr_repository" "app" {
  name                 = "${var.environment}-${local.function_name}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
  }
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
  ecr_repo_arn  = aws_ecr_repository.app.arn
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
  ecr_repo_url              = aws_ecr_repository.app.repository_url
  image_tag                 = var.app_image_tag
  database_url              = module.storage.db_connection_string
  lambda_log_group_name     = module.logging.lambda_log_group_name
  api_gateway_log_group_arn = module.logging.api_gateway_log_group_arn
}
