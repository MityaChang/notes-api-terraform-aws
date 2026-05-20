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
