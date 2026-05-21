#checkov:skip=CKV_AWS_338:30-day retention is intentional for cost-safe dev environment
#checkov:skip=CKV_AWS_158:KMS encryption for logs adds cost; not required for dev
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.environment}-${var.function_name}"
  retention_in_days = var.retention_days

  tags = {
    Environment = var.environment
  }
}

#checkov:skip=CKV_AWS_338:30-day retention is intentional for cost-safe dev environment
#checkov:skip=CKV_AWS_158:KMS encryption for logs adds cost; not required for dev
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.environment}-${var.api_name}"
  retention_in_days = var.retention_days

  tags = {
    Environment = var.environment
  }
}
