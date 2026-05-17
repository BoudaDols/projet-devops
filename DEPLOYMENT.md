# Deployment Guide & Architectural Decisions

## Architecture Overview

This project is a PHP/Go microservices platform composed of three services:

- `api-gateway` — Laravel app. Security gateway, reverse proxy, JWT auth, session management. All external requests go through it.
- `abonnement` — PHP app. Subscription management. Internal only.
- `user-service` — Go app. User profiles, preferences, activity history. Internal only.

Each service owns its own MySQL database. No shared database. Synchronous communication is HTTP via the gateway. Asynchronous communication uses Kafka.

---

## Repository Structure

```
Proj-devops/                        # Infrastructure repo
├── .github/workflows/
│   ├── tf-static-analysis.yml      # Terraform lint + validate + tfsec
│   └── infra.yml                   # Terraform apply (AWS + Azure)
├── terraform/
│   ├── modules/
│   │   ├── k8s-apps/               # Shared Kubernetes resources (all services + Kafka)
│   │   └── registry/               # ECR (AWS) or ACR (Azure)
│   ├── aws/                        # AWS infrastructure (VPC, EKS, S3, DynamoDB)
│   ├── aws-k8s/                    # AWS Kubernetes resources
│   └── azure/                      # Azure infrastructure (VNet, AKS)
├── kafka/k8s/local/                # Kafka local Kubernetes manifests
├── abonnement/                     # abonnement app + k8s manifests
├── api-gateway/                    # api-gateway app + k8s manifests
└── user-service/                   # user-service (Go) + k8s manifests
```

---

## Architectural Decisions

### 1. MySQL in-cluster
Each service runs its own MySQL instance inside the cluster as a Kubernetes Deployment with a PersistentVolumeClaim. This avoids the cost of managed database services while maintaining data isolation.

**Trade-off:** No automated backups or high availability. For production, consider migrating to managed DBs (RDS, Azure Database for MySQL).

### 2. Separate databases per service
Each service owns its own MySQL instance and database. This enforces microservice data ownership and prevents tight coupling at the data layer.

### 3. Internal services are ClusterIP only
`abonnement`, `user-service`, and `kafka` are never exposed externally. Network policies enforce that only authorized pods can reach each service.

### 4. api-gateway is the single entry point
All external traffic enters through `api-gateway`. It forwards `X-User-ID`, `X-User-Email`, `X-User-Name`, and `X-User-Role` headers to downstream services — internal services trust these headers without re-validating the JWT.

### 5. UUID-based user identity
Users are identified by a UUID (not integer ID) in the JWT payload. UUIDs are non-enumerable and safe to pass between services. The gateway forwards it as `X-User-ID`.

### 6. Kafka in KRaft mode
Kafka runs in KRaft mode (no Zookeeper) using `apache/kafka:3.7.0`. This simplifies the deployment to a single pod with no external coordinator dependency.

### 7. Terraform split into two stages (AWS)
AWS infrastructure (VPC, EKS) and Kubernetes resources are managed in two separate Terraform roots — `aws/` and `aws-k8s/`. This prevents the Kubernetes provider from timing out while the EKS cluster is still initializing.

### 8. Terraform manages infrastructure, not app deploys
Terraform provisions cloud infrastructure. App deployments (image updates) are handled by each app's own CD workflow using `kubectl set image`. Infrastructure changes and application releases are decoupled.

### 9. Terraform state backends
- **AWS:** S3 bucket with versioning and AES256 encryption + DynamoDB table for state locking
- **Azure:** Azure Blob Storage

### 10. AWS — t3.small node group
EKS uses a single `t3.small` managed node group. Fargate does not support EBS (gp2) persistent volumes required for MySQL. A single node keeps costs minimal (~$15/month).

### 11. Azure — mixed node pools
AKS uses a `Standard_B2s` system node pool for stateful workloads (MySQL) and a spot node pool for app pods. Spot nodes are up to 90% cheaper.

### 12. Secrets management
Secrets are never hardcoded:
- **Local:** manually applied via `kubectl create secret` or `deploy-local.sh`
- **CI/CD:** GitHub Actions secrets → `TF_VAR_*` env vars → Terraform `kubernetes_secret` resources
- **App CD:** GitHub Actions secrets → `kubectl create secret --dry-run | kubectl apply`

### 13. Local Kubernetes access
Docker Desktop's new kind-based Kubernetes (`desktop-control-plane`) does not forward NodePorts to `localhost` automatically. Use `kubectl port-forward` to access the gateway locally:
```bash
kubectl port-forward svc/api-gateway-service 8080:80 -n default
```

---

## GitHub Secrets Reference

### api-gateway repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | DockerHub credentials |
| `APP_KEY` | Laravel APP_KEY (`base64:...`) |
| `JWT_SECRET` | JWT signing secret |
| `DB_PASSWORD` | api-gateway MySQL root password |
| `KUBECONFIG_LOCAL` | kubeconfig for local cluster |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` | AWS credentials |
| `EKS_CLUSTER_NAME` | EKS cluster name |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `AKS_CLUSTER_NAME` / `AKS_RESOURCE_GROUP` | AKS cluster info |

### abonnement repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | DockerHub credentials |
| `DB_PASSWORD` | abonnement MySQL user password |
| `MYSQL_ROOT_PASSWORD` | abonnement MySQL root password |
| `KUBECONFIG_LOCAL` | kubeconfig for local cluster |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` | AWS credentials |
| `EKS_CLUSTER_NAME` | EKS cluster name |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `AKS_CLUSTER_NAME` / `AKS_RESOURCE_GROUP` | AKS cluster info |

### user-service repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | DockerHub credentials |
| `DB_PASSWORD` | user-service MySQL root password |
| `KUBECONFIG_LOCAL` | kubeconfig for local cluster |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` | AWS credentials |
| `EKS_CLUSTER_NAME` | EKS cluster name |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `AKS_CLUSTER_NAME` / `AKS_RESOURCE_GROUP` | AKS cluster info |

### Proj-devops (infra repo)

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `TF_BACKEND_BUCKET` / `TF_BACKEND_DYNAMODB_TABLE` | S3 backend config |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `TF_BACKEND_AZURE_RG` / `TF_BACKEND_AZURE_SA` / `TF_BACKEND_AZURE_CONTAINER` | Azure backend config |
| `APP_KEY` / `JWT_SECRET` | api-gateway secrets |
| `DB_PASSWORD_GATEWAY` | api-gateway MySQL root password |
| `DB_PASSWORD_ABONNEMENT` / `MYSQL_ROOT_PASSWORD` | abonnement DB passwords |
| `DB_PASSWORD_USER_SERVICE` | user-service MySQL root password |
| `DOCKERHUB_USERNAME` | DockerHub username |

---

## Prerequisites

- Docker Desktop with Kubernetes enabled
- `kubectl`
- `terraform` >= 1.7.0
- `go` >= 1.22
- AWS CLI configured with appropriate permissions
- Azure CLI logged in (`az login`)
- DockerHub account with repositories for `api-gateway`, `abonnement`, `user-service`

---

## How to Deploy

### 1. Local Kubernetes

```bash
# From the root of Proj-devops
./deploy-local.sh

# Access the gateway
kubectl port-forward svc/api-gateway-service 8080:80 -n default
# → http://localhost:8080
```

This script:
1. Builds Docker images for all three services
2. Deploys Kafka (KRaft mode)
3. Deploys abonnement + MySQL
4. Deploys api-gateway + MySQL + runs migrations
5. Deploys user-service + MySQL

---

### 2. AWS (first time)

**Step 1 — Create tfvars**

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
# Fill in terraform.tfvars with real values
```

**Step 2 — Bootstrap the S3 backend**

```bash
# Comment out backend.tf, then:
terraform init -reconfigure
terraform apply \
  -target=aws_s3_bucket.tfstate \
  -target=aws_s3_bucket_versioning.tfstate \
  -target=aws_s3_bucket_server_side_encryption_configuration.tfstate \
  -target=aws_dynamodb_table.tfstate_lock \
  -lock=false

# Uncomment backend.tf, then:
terraform init -migrate-state
```

**Step 3 — Apply infrastructure**

```bash
terraform apply
```

**Step 4 — Wait for cluster to be ready**

```bash
aws eks update-kubeconfig --region us-east-1 --name proj-devops-eks
kubectl get nodes  # wait until Ready
```

**Step 5 — Apply Kubernetes resources**

```bash
cd ../aws-k8s
cp ../aws/terraform.tfvars.example terraform.tfvars
# Fill in values (no eks_cluster_name needed)

terraform init
./import.sh     # only if resources already exist in the cluster
terraform apply
```

---

### 3. Azure (first time)

**Step 1 — Ensure blob backend exists**

```bash
az group create --name proj-devops-tfstate-rg --location eastus2
az storage account create --name projdevopstfstate --resource-group proj-devops-tfstate-rg --sku Standard_LRS
az storage container create --name tfstate --account-name projdevopstfstate
```

**Step 2 — Apply**

```bash
cd terraform/azure
cp terraform.tfvars.example terraform.tfvars

az login
terraform init
terraform apply
```

**Step 3 — Update kubeconfig**

```bash
az aks get-credentials --resource-group proj-devops-rg --name proj-devops-aks
```

---

### 4. App deployments (all environments)

Fully automated on push to `main` in any app repo:

1. CI runs (lint, static analysis, tests, Docker build & push to DockerHub)
2. CD triggers on CI success — deploys to local, AWS, and Azure simultaneously
3. `kubectl set image` updates the image tag to the commit SHA
4. Rollout monitored — fails if not complete within 120s

---

## How to Destroy

### Local Kubernetes

```bash
# All app resources
kubectl delete deployment abonnement api-gateway api-gateway-mysql mysql \
  user-service user-service-mysql kafka -n default
kubectl delete service abonnement api-gateway-service api-gateway-mysql-service \
  mysql user-service user-service-mysql kafka -n default
kubectl delete pvc --all -n default
kubectl delete secret api-gateway-secret abonnement-secrets mysql-secrets \
  user-service-secret -n default
kubectl delete configmap api-gateway-config abonnement-config \
  user-service-config -n default
kubectl delete networkpolicy --all -n default
```

### AWS — Kubernetes resources only

```bash
cd terraform/aws-k8s
terraform destroy
```

### AWS — Full infrastructure (EKS + VPC)

```bash
cd terraform/aws
terraform destroy
```

> The S3 bucket and DynamoDB table have `prevent_destroy = true`. To destroy them:
> 1. Remove `lifecycle { prevent_destroy = true }` from `aws/main.tf`
> 2. `terraform init -migrate-state` — migrate state back to local
> 3. `terraform destroy`

### Azure — Full infrastructure

```bash
cd terraform/azure
terraform destroy
```

> Azure Blob Storage backend must be deleted manually:
> ```bash
> az storage container delete --name tfstate --account-name projdevopstfstate
> az storage account delete --name projdevopstfstate --resource-group proj-devops-tfstate-rg --yes
> az group delete --name proj-devops-tfstate-rg --yes
> ```

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
      ├── deploy-aws        (terraform/aws  → VPC + EKS)
      ├── deploy-aws-k8s    (terraform/aws-k8s → all k8s resources)
      └── deploy-azure      (terraform/azure → VNet + AKS + all k8s resources)
```
