terraform {
  backend "s3" {
    bucket         = "proj-devops-tfstate"
    key            = "aws/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "proj-devops-tfstate-lock"
    encrypt        = true
  }
}
