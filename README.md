# Proj-devops — Infrastructure & DevOps

Infrastructure repository for a PHP microservices platform. Manages Kubernetes deployments, Terraform infrastructure for AWS and Azure, CI/CD pipelines, and local development environment.

---

## Services

| Service | Technology | Role |
|---|---|---|
| `api-gateway` | Laravel 12 / PHP 8.2 | Security gateway, reverse proxy, JWT auth, session management, load balancer |
| `abonnement` | PHP 8.4 | Subscription management service — internal only |

All external traffic enters through `api-gateway`. The `abonnement` service is never exposed directly — it is only reachable from within the cluster by the gateway.

---

## Architecture

```
Internet
   │
   ▼
api-gateway (LoadBalancer :80)
   │  JWT auth + rate limiting + request logging
   │  forwards to → SERVICE_*_URL
   │
   ▼
abonnement (ClusterIP — internal only)
   │
   ▼
MySQL (per service — no shared DB)
```

Each service owns its own MySQL instance running inside the cluster. No shared database. Inter-service communication is currently synchronous HTTP via the gateway. Kafka is planned for future async communication.

---

## Repository Structure

```
Proj-devops/
├── .github/
│   └── workflows/
│       ├── tf-static-analysis.yml   # Terraform fmt + validate + tfsec (on every PR)
│       └── infra.yml                # Terraform apply — triggers on terraform/** changes
├── terraform/
│   ├── modules/
│   │   ├── k8s-apps/                # Shared k8s resources (deployments, services, secrets, network policies)
│   │   └── registry/                # ECR (AWS) or ACR (Azure)
│   ├── aws/                         # Stage 1 — VPC + EKS + S3/DynamoDB backend
│   ├── aws-k8s/                     # Stage 2 — Kubernetes resources on EKS
│   └── azure/                       # AKS + VNet + k8s resources
├── abonnement/                      # abonnement service (submodule / sibling repo)
│   ├── k8s/local/                   # Local Kubernetes manifests
│   └── .github/workflows/
│       ├── ci.yml                   # Lint + static analysis + tests + Docker build
│       └── cd.yml                   # Deploy to local + AWS + Azure
├── api-gateway/                     # api-gateway service (submodule / sibling repo)
│   ├── k8s/local/                   # Local Kubernetes manifests
│   └── .github/workflows/
│       ├── ci.yml                   # Lint + static analysis + tests + Docker build
│       └── cd.yml                   # Deploy to local + AWS + Azure
├── deploy-local.sh                  # One-command local deployment
├── DEPLOYMENT.md                    # Architecture decisions + full deploy/destroy guide
└── COMMANDS.md                      # Quick reference for all commands
```

---

## Environments

| Environment | Cluster | Exposed at | Infrastructure |
|---|---|---|---|
| Local | Docker Desktop | `http://localhost:30080` | `deploy-local.sh` |
| AWS | EKS (us-east-1) | LoadBalancer DNS | Terraform `aws/` + `aws-k8s/` |
| Azure | AKS (eastus2) | LoadBalancer IP | Terraform `azure/` |

---

## api-gateway Features

| Feature | Status |
|---|---|
| JWT authentication (HMAC-SHA256) | ✅ |
| User registration & login | ✅ |
| Token refresh | ✅ |
| Token blacklist (logout) | ✅ |
| Role-based access control (user / admin) | ✅ |
| Service proxy / reverse proxy | ✅ |
| Rate limiting (login: 5/min, register: 10/hr, api: 60/min) | ✅ |
| CORS configuration | ✅ |
| Structured JSON request logging (stdout) | ✅ |
| Phone + OTP authentication (V2) | ✅ |
| Admin role management | ✅ |

### Service Proxy

The gateway auto-discovers microservices from environment variables. Any `SERVICE_*_URL` variable is automatically registered as a routable service — no code changes needed.

```
GET /api/services/abonnement/plans
Authorization: Bearer <jwt>

→ forwards to SERVICE_ABONNEMENT_URL/plans
  with headers: X-User-Email, X-User-Name, X-User-Role
```

---

## CI/CD Pipeline

### App repositories (api-gateway, abonnement)

```
push to any branch
      │
      ▼
   CI workflow
   ├── Lint (PHPCS / Pint)
   ├── Static analysis (PHPStan)
   ├── Security scan (Semgrep)
   ├── Dependency audit (composer audit / npm audit)
   ├── Tests (PHPUnit)
   └── Build & push to DockerHub (main branch only)
            │
            │ on CI success (main only)
            ▼
         CD workflow
         ├── deploy-local   (self-hosted runner)
         ├── deploy-aws     (EKS — kubectl set image)
         └── deploy-azure   (AKS — kubectl set image)
```

### Infrastructure repository (Proj-devops)

```
push to main (terraform/** files changed)
      │
      ├── tf-static-analysis (every push/PR)
      │   ├── terraform fmt -check
      │   ├── terraform validate
      │   └── tfsec
      │
      └── infra.yml (main only)
          ├── terraform apply (aws/)      → VPC + EKS
          ├── terraform apply (aws-k8s/)  → k8s resources
          └── terraform apply (azure/)    → AKS + k8s resources
```

---

## Infrastructure

### AWS

| Resource | Type | Purpose |
|---|---|---|
| VPC | 2 AZs, private + public subnets | Network isolation |
| EKS | v1.30, `t3.small` node | Kubernetes cluster |
| S3 | Versioned + AES256 encrypted | Terraform state |
| DynamoDB | PAY_PER_REQUEST | Terraform state locking |

AWS Terraform is split into two stages to avoid provider timeout issues:
- `terraform/aws/` — provisions VPC and EKS cluster
- `terraform/aws-k8s/` — deploys Kubernetes resources after the cluster is ready

### Azure

| Resource | Type | Purpose |
|---|---|---|
| VNet | Single subnet | Network isolation |
| AKS system pool | `Standard_B2s` (1 node) | Stable node for MySQL |
| AKS spot pool | `Standard_B2s` spot | App pods (up to 90% cheaper) |

### Kubernetes (both clouds)

| Resource | Description |
|---|---|
| `api-gateway` Deployment | 1 replica, liveness + readiness probes |
| `abonnement` Deployment | 1 replica, init container runs migrations |
| `api-gateway-mysql` Deployment | MySQL 8.0, 1Gi PVC |
| `mysql` Deployment | MySQL 8.0, 5Gi PVC |
| `api-gateway-service` | LoadBalancer (cloud) / NodePort 30080 (local) |
| `abonnement` Service | ClusterIP — internal only |
| Network policies | Only `api-gateway` pods can reach `abonnement` on port 8080 |
| `api-gateway-migrations` Job | Runs `php artisan migrate --force` on deploy |

---

## Security

- JWT tokens signed with HMAC-SHA256, validated on every request
- Token blacklist prevents use of logged-out tokens
- `abonnement` is ClusterIP only — unreachable from outside the cluster
- Network policies enforce that only `api-gateway` pods can reach `abonnement`
- Secrets never hardcoded — injected at runtime via GitHub Actions secrets → Kubernetes secrets
- Rate limiting on all auth endpoints
- Semgrep SAST scanning on every push
- Trivy Docker image CVE scanning on every build
- tfsec Terraform security scanning on every infra PR

---

## Getting Started

### Prerequisites

- Docker Desktop with Kubernetes enabled
- `kubectl`
- `terraform` >= 1.7.0
- AWS CLI
- Azure CLI

### Local deployment

```bash
git clone <this-repo>
cd Proj-devops

./deploy-local.sh
```

Gateway available at `http://localhost:30080`

### AWS deployment

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
# Fill in values

terraform init -reconfigure
terraform apply -target=aws_s3_bucket.tfstate \
  -target=aws_s3_bucket_versioning.tfstate \
  -target=aws_s3_bucket_server_side_encryption_configuration.tfstate \
  -target=aws_dynamodb_table.tfstate_lock \
  -lock=false

terraform init -migrate-state
terraform apply

aws eks update-kubeconfig --region us-east-1 --name proj-devops-eks
kubectl get nodes  # wait for Ready

cd ../aws-k8s
cp ../aws/terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

### Azure deployment

```bash
cd terraform/azure
cp terraform.tfvars.example terraform.tfvars
# Fill in values

az login
terraform init
terraform apply
```

---

## Secrets Reference

### api-gateway repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | DockerHub credentials |
| `APP_KEY` | Laravel application key |
| `JWT_SECRET` | JWT signing secret |
| `DB_PASSWORD` | api-gateway MySQL root password |
| `KUBECONFIG_LOCAL` | Local cluster kubeconfig |
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
| `KUBECONFIG_LOCAL` | Local cluster kubeconfig |
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
| `DB_PASSWORD_GATEWAY` / `DB_PASSWORD_ABONNEMENT` / `MYSQL_ROOT_PASSWORD` | Database passwords |
| `DOCKERHUB_USERNAME` | DockerHub username |

---

## Documentation

| File | Description |
|---|---|
| `DEPLOYMENT.md` | Full architectural decisions, deploy steps, and destroy guide |
| `COMMANDS.md` | Quick reference for every kubectl, AWS, Azure, and Terraform command |

---

## Roadmap

- [ ] Azure deployment (pending Azure AD service principal)
- [ ] Kafka for async inter-service communication
- [ ] Prometheus + Grafana observability stack
- [ ] Additional microservices
