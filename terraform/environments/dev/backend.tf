# Remote state on S3 with DynamoDB locking
# Requires pre-existing S3 bucket + DynamoDB table + IAM permissions.
terraform {
  backend "s3" {
    bucket         = "notes-api-tf-state-ap-southeast-1"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# Local state for testing and development
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }