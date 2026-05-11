terraform {
  backend "s3" {
    bucket         = "proj-devops-tfstate"
    key            = "aws-k8s/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "proj-devops-tfstate-lock"
    encrypt        = true
  }
}
