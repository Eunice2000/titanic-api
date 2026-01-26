terraform {
  backend "s3" {
    bucket         = "titanic-api-terraform-state-file"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "titanic-terraform-locks"
  }
}
