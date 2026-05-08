# Deployment Guide & Architectural Decisions

## Architecture Overview

This project is a microservices system composed of two services:

- `api-gateway` — Laravel app. Acts as the security gateway, reverse proxy, load balancer, and session/JWT token manager. All external requests go through it.
- `abonnement` — PHP app. Handles subscription logic. Internal only — never exposed directly to the outside world.

Each service has its own MySQL database running inside the cluster. No shared database.

Inter-service communication is currently HTTP (via the gateway). Kafka is planned for future async communication between services.

---

## Repository Structure

```
Proj-devops/                        # Infrastructure repo
├── .github/workflows/
│   ├── tf-static-analysis.yml      # Terraform lint + validate + tfsec
│   └── infra.yml                   # Terraform apply (AWS + Azure)
├── terraform/
│   ├── modules/
│   │   ├── k8s-apps/               # Shared Kubernetes resources
│   │   └── registry/               # ECR (AWS) or ACR (Azure)
│   ├── aws/                        # AWS-specific infrastructure
│   └── azure/                      # Azure-specific infrastructure
├── abonnement/                     # abonnement app + k8s manifests
│   └── .github/workflows/
│       ├── ci.yml                  # lint, tests, build & push to DockerHub
│       └── cd.yml                  # deploy to local + AWS + Azure
└── api-gateway/                    # api-gateway app + k8s manifests
    └── .github/workflows/
        ├── ci.yml                  # lint, tests, build & push to DockerHub
        └── cd.yml                  # deploy to local + AWS + Azure
```

---

## Architectural Decisions

### 1. MySQL in-cluster
Each service runs its own MySQL instance inside the cluster as a Kubernetes Deployment with a PersistentVolumeClaim. This avoids the cost of managed database services (RDS, Azure Database for MySQL) while maintaining data isolation between services.

**Trade-off:** No automated backups or high availability. Acceptable for development and staging. For production, consider migrating to managed DBs.

### 2. Separate databases per service
`api-gateway` and `abonnement` each have their own MySQL instance and database. This enforces microservice data ownership and prevents tight coupling at the data layer.

### 3. abonnement is ClusterIP only
`abonnement` is never exposed externally. Its Kubernetes Service is `ClusterIP`, meaning it is only reachable from within the cluster. The network policy enforces that only pods labeled `app: api-gateway` can reach it on port 8080.

### 4. api-gateway is the single entry point
All external traffic enters through `api-gateway`. On local it is exposed via `NodePort 30080`. On AWS and Azure it is exposed via a cloud `LoadBalancer` service.

### 5. Terraform manages infrastructure, not app deploys
Terraform provisions and manages cloud infrastructure (VPC/VNet, EKS/AKS, node groups, Kubernetes resources). App deployments (image updates) are handled by each app's own CD workflow using `kubectl set image` and `kubectl rollout restart`. This keeps infrastructure changes and application releases decoupled.

### 6. Terraform state backends
- **AWS:** S3 bucket with versioning and AES256 encryption + DynamoDB table for state locking
- **Azure:** Azure Blob Storage (pre-existing)

### 7. AWS — t3.small node group
EKS uses a single `t3.small` managed node group instead of Fargate. Fargate does not support EBS (gp2) persistent volumes, which are required for MySQL. A single node keeps costs minimal (~$15/month) while supporting stateful workloads.

### 8. Azure — mixed node pools
AKS uses a `Standard_B2s` system node pool for stable stateful workloads (MySQL) and a spot node pool for app pods (api-gateway, abonnement). Spot nodes are up to 90% cheaper but can be evicted — acceptable for stateless app pods, not for databases.

### 9. Secrets management
Secrets are never hardcoded. They flow as:
- **Local:** manually applied via `kubectl create secret` or `deploy-local.sh`
- **CI/CD:** GitHub Actions secrets → `TF_VAR_*` env vars → Terraform `kubernetes_secret` resources
- **App CD:** GitHub Actions secrets → `kubectl create secret --dry-run | kubectl apply`

### 10. Kafka (future)
When Kafka is added, a dedicated network policy will be applied to the Kafka broker pod allowing only service pods to produce/consume on port 9092. The gateway will not be involved in Kafka traffic — it handles only synchronous HTTP.

---

## GitHub Secrets Reference

### api-gateway repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub access token |
| `APP_KEY` | Laravel APP_KEY (`base64:...`) |
| `JWT_SECRET` | JWT signing secret |
| `DB_PASSWORD` | api-gateway MySQL root password |
| `KUBECONFIG_LOCAL` | kubeconfig for local docker-desktop cluster |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `AWS_REGION` | AWS region (us-east-1) |
| `EKS_CLUSTER_NAME` | EKS cluster name |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `AKS_CLUSTER_NAME` | AKS cluster name |
| `AKS_RESOURCE_GROUP` | AKS resource group name |

### abonnement repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub access token |
| `DB_PASSWORD` | abonnement MySQL user password |
| `MYSQL_ROOT_PASSWORD` | abonnement MySQL root password |
| `KUBECONFIG_LOCAL` | kubeconfig for local docker-desktop cluster |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `AWS_REGION` | AWS region (us-east-1) |
| `EKS_CLUSTER_NAME` | EKS cluster name |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `AKS_CLUSTER_NAME` | AKS cluster name |
| `AKS_RESOURCE_GROUP` | AKS resource group name |

### Proj-devops (infra repo)

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `TF_BACKEND_BUCKET` | S3 bucket name for Terraform state |
| `TF_BACKEND_DYNAMODB_TABLE` | DynamoDB table name for state locking |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `TF_BACKEND_AZURE_RG` | Azure resource group for blob backend |
| `TF_BACKEND_AZURE_SA` | Azure storage account for blob backend |
| `TF_BACKEND_AZURE_CONTAINER` | Azure blob container name |
| `APP_KEY` | Laravel APP_KEY |
| `JWT_SECRET` | JWT signing secret |
| `DB_PASSWORD_GATEWAY` | api-gateway MySQL root password |
| `DB_PASSWORD_ABONNEMENT` | abonnement MySQL user password |
| `MYSQL_ROOT_PASSWORD` | abonnement MySQL root password |
| `DOCKERHUB_USERNAME` | DockerHub username |

---

## How to Deploy

### Prerequisites

- Docker Desktop with Kubernetes enabled
- `kubectl` installed and context set to `docker-desktop`
- `terraform` >= 1.7.0
- AWS CLI configured with appropriate permissions
- Azure CLI logged in (`az login`)
- DockerHub account with repositories created for `api-gateway` and `abonnement`

---

### 1. Local Kubernetes

```bash
# From the root of Proj-devops
./deploy-local.sh
```

This script:
1. Builds both Docker images locally
2. Applies secrets, configmaps, MySQL, and app deployments in the correct order
3. Runs api-gateway migrations
4. Confirms the gateway is reachable at http://localhost:30080

---

### 2. AWS (first time)

**Step 1 — Bootstrap the S3 backend**

The S3 bucket and DynamoDB table are defined in `terraform/aws/main.tf` but the backend config in `backend.tf` references them. On first apply, comment out `backend.tf`, apply to create the resources, then uncomment and run `terraform init` to migrate state.

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
# Fill in terraform.tfvars with real values

# First apply — local backend
terraform init
terraform apply -target=aws_s3_bucket.tfstate -target=aws_dynamodb_table.tfstate_lock

# Migrate to S3 backend
# Uncomment backend.tf, then:
terraform init -migrate-state
terraform apply
```

**Step 2 — Update kubeconfig**

```bash
aws eks update-kubeconfig --region us-east-1 --name proj-devops-eks
```

**Step 3 — Subsequent deploys**

Push to `main` in the infra repo with changes under `terraform/` — the `infra.yml` workflow handles it automatically.

---

### 3. Azure (first time)

**Step 1 — Ensure blob backend exists**

The Azure Blob Storage backend must exist before running `terraform init`. Create it manually or via Azure CLI:

```bash
az group create --name proj-devops-tfstate-rg --location eastus2
az storage account create --name projdevopstfstate --resource-group proj-devops-tfstate-rg --sku Standard_LRS
az storage container create --name tfstate --account-name projdevopstfstate
```

**Step 2 — Apply**

```bash
cd terraform/azure
cp terraform.tfvars.example terraform.tfvars
# Fill in terraform.tfvars with real values

az login
terraform init
terraform apply
```

**Step 3 — Update kubeconfig**

```bash
az aks get-credentials --resource-group proj-devops-rg --name proj-devops-aks
```

**Step 4 — Subsequent deploys**

Push to `main` in the infra repo with changes under `terraform/` — the `infra.yml` workflow handles it automatically.

---

### 4. App deployments (all environments)

App deployments are fully automated. Push to `main` in either app repo:

1. CI runs (lint, static analysis, tests, Docker build & push to DockerHub)
2. On CI success, CD triggers and deploys to local, AWS, and Azure simultaneously
3. Each deploy uses `kubectl set image` to update the image tag to the commit SHA
4. Rollout status is monitored — workflow fails if the rollout does not complete within 120s

---

## CI/CD Flow Summary

```
App push to main
      │
      ▼
   CI workflow
   (lint → analyse → test → build & push to DockerHub)
      │
      │ on success
      ▼
   CD workflow
      ├── deploy-local  (self-hosted runner, kubectl rollout restart)
      ├── deploy-aws    (ubuntu-latest, aws eks + kubectl set image)
      └── deploy-azure  (ubuntu-latest, az aks + kubectl set image)

Infra push to main (terraform/** files)
      │
      ▼
   tf-static-analysis (fmt + validate + tfsec) — on every push/PR
      │
   infra.yml (terraform apply)
      ├── deploy-aws   (S3 backend)
      └── deploy-azure (Azure Blob backend)
```
