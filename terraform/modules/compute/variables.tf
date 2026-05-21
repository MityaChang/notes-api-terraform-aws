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

variable "ecr_repo_url" {
  description = "ECR repository URL"
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

variable "reserved_concurrency" {
  description = "Reserved concurrent executions for Lambda"
  type        = number
  default     = 5
}
