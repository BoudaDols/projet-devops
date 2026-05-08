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
# VPC
# ─────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "proj-devops-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # cheapest — one NAT for all AZs
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ─────────────────────────────────────────────
# EKS Cluster
# ─────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"] # cheapest viable node for stateful workloads
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }
}

# ─────────────────────────────────────────────
# S3 + DynamoDB for Terraform state backend
# (bootstrap — only needed on first apply)
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "tfstate" {
  bucket = "proj-devops-tfstate"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "proj-devops-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ─────────────────────────────────────────────
# Kubernetes provider — uses EKS cluster
# ─────────────────────────────────────────────
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
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

  app_key                = var.app_key
  jwt_secret             = var.jwt_secret
  gateway_db_password    = var.gateway_db_password
  abonnement_db_password = var.abonnement_db_password
  mysql_root_password    = var.mysql_root_password

  depends_on = [module.eks]
}
