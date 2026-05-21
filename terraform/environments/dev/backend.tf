# Remote state on S3 with DynamoDB locking
terraform {
  backend "s3" {
    bucket         = "notes-api-tf-state-ap-southeast-1"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
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
