terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────
# Read EKS outputs from aws/ remote state
# ─────────────────────────────────────────────
data "terraform_remote_state" "aws" {
  backend = "s3"

  config = {
    bucket = "proj-devops-tfstate"
    key    = "aws/terraform.tfstate"
    region = var.aws_region
  }
}

# ─────────────────────────────────────────────
# Kubernetes provider — uses EKS cluster
# ─────────────────────────────────────────────
# ─────────────────────────────────────────────
# Kubernetes provider — uses EKS cluster
# ─────────────────────────────────────────────
provider "kubernetes" {
  host                   = data.terraform_remote_state.aws.outputs.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.aws.outputs.eks_cluster_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.aws.outputs.eks_cluster_name, "--region", var.aws_region]
  }
}

# ─────────────────────────────────────────────
# k8s-apps module
# ─────────────────────────────────────────────
module "k8s_apps" {
  source = "../modules/k8s-apps"

  namespace          = "default"
  dockerhub_username = var.dockerhub_username
  image_tag          = var.image_tag
  storage_class      = "gp2"

  app_key                  = var.app_key
  jwt_secret               = var.jwt_secret
  gateway_db_password      = var.gateway_db_password
  abonnement_db_password   = var.abonnement_db_password
  mysql_root_password      = var.mysql_root_password
  user_service_db_password = var.user_service_db_password
  smtp_user                = var.smtp_user
  smtp_pass                = var.smtp_pass
  default_recipient        = var.default_recipient
  pdf_service_db_password  = var.pdf_service_db_password
}
