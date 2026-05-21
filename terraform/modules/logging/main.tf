resource "aws_cloudwatch_log_group" "lambda" {
  #checkov:skip=CKV_AWS_338:30-day retention is intentional for cost-safe dev environment
  #checkov:skip=CKV_AWS_158:KMS encryption for logs adds cost; not required for dev
  name              = "/aws/lambda/${var.environment}-${var.function_name}"
  retention_in_days = var.retention_days

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  #checkov:skip=CKV_AWS_338:30-day retention is intentional for cost-safe dev environment
  #checkov:skip=CKV_AWS_158:KMS encryption for logs adds cost; not required for dev
  name              = "/aws/apigateway/${var.environment}-${var.api_name}"
  retention_in_days = var.retention_days

  tags = {
    Environment = var.environment
  }
}
