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
