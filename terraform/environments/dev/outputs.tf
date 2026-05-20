output "api_url" {
  description = "API Gateway invoke URL"
  value       = module.compute.api_url
}

output "ecr_repo_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.storage.db_endpoint
}
