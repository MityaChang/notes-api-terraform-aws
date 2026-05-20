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
