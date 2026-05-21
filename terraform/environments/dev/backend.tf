# Remote state on S3 with DynamoDB locking
terraform {
  backend "s3" {
    bucket         = "notes-api-tf-state-760638704957"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# To use local state instead (e.g., for quick evaluator testing):
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
