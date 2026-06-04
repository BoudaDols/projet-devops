# Proj-devops — Infrastructure & DevOps

Infrastructure repository for a PHP/Go microservices platform. Manages Kubernetes deployments, Terraform infrastructure for AWS and Azure, CI/CD pipelines, and local development environment.

---

## Services

| Service | Technology | Role |
|---|---|---|
| `api-gateway` | Laravel 12 / PHP 8.4 | Security gateway, reverse proxy, JWT auth, session management, load balancer |
| `abonnement` | PHP 8.4 | Subscription management — internal only |
| `user-service` | Go 1.22 / Gin | User profiles, preferences, activity history — internal only |
| `notification-service` | Python 3.12 / Flask | Event-driven email notifications — internal only |
| `pdf-service` | Python 3.12 / FastAPI | PDF access control based on subscription plan — internal only |

All external traffic enters through `api-gateway`. Internal services are never exposed directly — they are only reachable from within the cluster via the gateway.

---

## Architecture

```
                          Internet
                             │
                             ▼
                    ┌─────────────────┐
                    │   api-gateway   │  LoadBalancer :80
                    │  Laravel / PHP  │  JWT auth + rate limiting
                    │                 │  request logging + CORS
                    └────────┬────────┘
                             │
      ┌──────────────┬───────┼───────┬──────────────┐
      │ HTTP (sync)  │       │       │              │ HTTP (sync)
      ▼              │       │       │              ▼
┌───────────────┐    │       │       │   ┌──────────────────────┐
│  abonnement   │    │       │       │   │    user-service       │
│  PHP 8.4      │    │       │       │   │    Go / Gin           │
│  ClusterIP    │    │       │       │   │    ClusterIP          │
└──────┬────────┘    │       │       │   └──────────┬────────────┘
       │             │       │       │              │
       ▼             │       │       │              ▼
  MySQL 8.0          │       │       │         MySQL 8.0
  (abonnement)       │       │       │         (user_service)
                     │       │       │
                     ▼       │       ▼
          ┌───────────────┐  │  ┌──────────────────┐
          │  pdf-service  │  │  │ notification-svc  │
          │  FastAPI      │  │  │ Flask             │
          │  ClusterIP    │  │  │ ClusterIP         │
          └──┬───┬───┬────┘  │  └──────────────────┘
             │   │   │       │           ▲
             ▼   ▼   ▼       │           │ Kafka consume
        Redis MySQL S3/Blob  │           │
                             │           │
              ┌──────────────┘           │
              │ Kafka events             │
              ▼                          │
   ┌──────────────────┐                 │
   │     Kafka        │  apache/kafka:3.7.0
   │     KRaft mode   │  ClusterIP :9092
   └──────────────────┘─────────────────┘
   └──────────────────┘
              │
    ┌─────────┴────────────────────┐
    │ user.registered               │  → user-service creates profile
    │ subscription.changed          │  → user-service logs activity
    │                               │  → notification-service sends email
    │ payment.succeeded             │  → notification-service sends receipt
    │ payment.failed                │  → notification-service sends alert
    │ user.profile_updated          │  → future: notification-service
    └───────────────────────────────┘
              │
              ▼
   ┌──────────────────────┐
   │  notification-service │  Python 3.12 / Flask
   │  Kafka consumer       │  ClusterIP :5000
   │  SMTP email sender    │  No database
   └──────────────────────┘
              │
              ▼
         SMTP (Mailtrap)
              │
              ▼
         User inbox

   api-gateway MySQL 8.0
   (api_gateway DB — auth, sessions, cache, queue)
```

**Communication patterns:**
- Synchronous HTTP — client → gateway → service (via `SERVICE_*_URL` auto-discovery)
- Asynchronous Kafka — services publish/consume events independently of the gateway
- All services ClusterIP — network policies enforce strict pod-to-pod access

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
│   │   ├── k8s-apps/                # Shared k8s resources (all services, Kafka, network policies)
│   │   └── registry/                # ECR (AWS) or ACR (Azure)
│   ├── aws/                         # Stage 1 — VPC + EKS + S3/DynamoDB backend
│   ├── aws-k8s/                     # Stage 2 — Kubernetes resources on EKS
│   └── azure/                       # AKS + VNet + k8s resources
├── kafka/
│   └── k8s/local/                   # Kafka local Kubernetes manifests
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
├── notification-service/            # notification-service (Python/Flask)
│   ├── k8s/                         # Production Kubernetes manifests
│   ├── k8s/local/                   # Local Kubernetes manifests
│   └── .github/workflows/
│       ├── ci.yml                   # Lint (flake8) + tests (pytest)
│       └── cd.yml                   # Build + deploy to local + AWS + Azure
├── pdf-service/                     # pdf-service (Python/FastAPI)
│   ├── k8s/                         # Production Kubernetes manifests
│   ├── k8s/local/                   # Local Kubernetes manifests
│   └── .github/workflows/
│       ├── ci.yml                   # Lint (ruff) + tests (pytest)
│       └── cd.yml                   # Build + deploy to local + AWS + Azure
├── user-service/                    # user-service (Go)
│   ├── k8s/local/                   # Local Kubernetes manifests
│   └── .github/workflows/
│       ├── ci.yml                   # Lint + tests + Docker build
│       └── cd.yml                   # Deploy to local + AWS + Azure
├── deploy-local.sh                  # One-command local deployment
├── DEPLOYMENT.md                    # Architecture decisions + full deploy/destroy guide
└── COMMANDS.md                      # Quick reference for all commands
```

---

## Environments

| Environment | Cluster | Exposed at | Infrastructure |
|---|---|---|---|
| Local | Docker Desktop | `kubectl port-forward svc/api-gateway-service 8080:80` | `deploy-local.sh` |
| AWS | EKS (us-east-1) | LoadBalancer DNS | Terraform `aws/` + `aws-k8s/` |
| Azure | AKS (eastus2) | LoadBalancer IP | Terraform `azure/` |

---

## api-gateway Features

| Feature | Status |
|---|---|
| JWT authentication (HMAC-SHA256) | ✅ |
| User UUID in JWT payload | ✅ |
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
| X-User-ID header forwarding to services | ✅ |

### Service Proxy

The gateway auto-discovers microservices from environment variables. Any `SERVICE_*_URL` variable is automatically registered as a routable service — no code changes needed.

```
GET /api/services/abonnement/plans
Authorization: Bearer <jwt>

→ forwards to SERVICE_ABONNEMENT_URL/plans
  with headers: X-User-ID, X-User-Email, X-User-Name, X-User-Role

GET /api/services/user/profiles/<uuid>
Authorization: Bearer <jwt>

→ forwards to SERVICE_USER_URL/profiles/<uuid>
  with headers: X-User-ID, X-User-Email, X-User-Name, X-User-Role
```

---

## user-service Features

| Feature | Status |
|---|---|
| Profile CRUD (display name, avatar, bio, language, timezone) | ✅ |
| Generic key/value preferences | ✅ |
| Activity history (profile updates, preferences, subscriptions, API requests) | ✅ |
| Kafka consumer — `user.registered` → auto-create profile | ✅ |
| Kafka consumer — `subscription.changed` → log activity | ✅ |
| Kafka producer — `user.profile_updated`, `user.preferences_updated` | ✅ |
| DB migrations on startup | ✅ |

---

## notification-service Features

| Feature | Status |
|---|---|
| Kafka consumer — `subscription.changed` → subscription confirmation email | ✅ |
| Kafka consumer — `subscription.changed` → cancellation email | ✅ |
| Kafka consumer — `payment.succeeded` → payment receipt email | ✅ |
| Kafka consumer — `payment.failed` → payment failure alert email | ✅ |
| SMTP email sending via smtplib (Mailtrap) | ✅ |
| Plain-text email templates per event type | ✅ |
| Fallback recipient when `user_email` absent from event | ✅ |
| `/health` endpoint for Kubernetes probes | ✅ |
| Fault-tolerant — SMTP/Kafka errors never crash the consumer loop | ✅ |

---

## pdf-service Features

| Feature | Status |
|---|---|
| PDF catalog (list, get metadata) | 🔲 |
| Open reading session — returns pre-signed URL from S3/Azure Blob | 🔲 |
| Close reading session — persists duration to MySQL | 🔲 |
| Free plan: 1 PDF/day, 30 minutes max reading time | 🔲 |
| Basic plan: 1 PDF/day, unlimited reading time | 🔲 |
| Premium plan: unlimited PDFs, unlimited time | 🔲 |
| Redis-based real-time session & daily counter tracking | 🔲 |
| MySQL reading history (logged on session close) | 🔲 |
| S3 and Azure Blob storage abstraction (switchable via env) | 🔲 |
| `/health` endpoint for Kubernetes probes | 🔲 |
| Network policy — only api-gateway can reach it | 🔲 |

---

## CI/CD Pipeline

### App repositories (api-gateway, abonnement, user-service, notification-service, pdf-service)

```
push to any branch
      │
      ▼
   CI workflow
   ├── Lint
   ├── Static analysis
   ├── Tests
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
| `pdf-service` Deployment | 1 replica, FastAPI + Redis sessions + S3/Blob storage |
| `pdf-service-mysql` Deployment | MySQL 8.0, 1Gi PVC (reading history) |
| `pdf-service-redis` Deployment | Redis 7, session counters + daily limits |
| `redis` Deployment | Redis 7 alpine, no persistence — cache/sessions/queue for api-gateway |
| `notification-service` Deployment | 1 replica, Kafka consumer thread + Flask /health |
| `api-gateway` Deployment | 1 replica, liveness + readiness probes |
| `abonnement` Deployment | 1 replica, init container runs migrations |
| `user-service` Deployment | 1 replica, runs DB migrations on startup |
| `kafka` Deployment | apache/kafka:3.7.0, KRaft mode, 2Gi PVC |
| `api-gateway-mysql` Deployment | MySQL 8.0, 1Gi PVC |
| `mysql` Deployment | MySQL 8.0, 5Gi PVC (abonnement) |
| `user-service-mysql` Deployment | MySQL 8.0, 1Gi PVC |
| `api-gateway-service` | LoadBalancer (cloud) / port-forward (local) |
| `abonnement` Service | ClusterIP — internal only |
| `notification-service` Service | ClusterIP — internal only (health probe only) |
| `pdf-service` Service | ClusterIP — internal only |
| `user-service` Service | ClusterIP — internal only |
| `kafka` Service | ClusterIP — internal only |
| Network policies | Strict pod-to-pod access control |
| `api-gateway-migrations` Job | Runs `php artisan migrate --force` on deploy |

---

## Security

- JWT tokens signed with HMAC-SHA256, validated on every request
- UUID-based user identity — non-enumerable, forwarded as `X-User-ID` to all services
- Token blacklist prevents use of logged-out tokens (Redis-backed with TTL)
- Access/refresh token model — access token 1h, refresh token 7 days in Redis
- Redis network policy — only api-gateway can reach Redis on port 6379
- All internal services are ClusterIP only — unreachable from outside the cluster
- Network policies enforce strict pod-to-pod access (only gateway can reach internal services)
- Kafka network policy — only service pods can produce/consume on port 9092
- notification-service network policy — only egress to Kafka (9092) and SMTP (2525/587/465)
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
- `go` >= 1.22
- AWS CLI
- Azure CLI

### Local deployment

```bash
git clone <this-repo>
cd Proj-devops

./deploy-local.sh

# Access the gateway
kubectl port-forward svc/api-gateway-service 8080:80 -n default
# → http://localhost:8080
```

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

### notification-service repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | DockerHub credentials |
| `SMTP_USER` | Mailtrap SMTP username |
| `SMTP_PASS` | Mailtrap SMTP password |
| `DEFAULT_RECIPIENT` | Fallback recipient email |
| `KUBECONFIG_LOCAL` | Local cluster kubeconfig |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` | AWS credentials |
| `EKS_CLUSTER_NAME` | EKS cluster name |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `AKS_CLUSTER_NAME` / `AKS_RESOURCE_GROUP` | AKS cluster info |

### pdf-service repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | DockerHub credentials |
| `DB_PASSWORD` | pdf-service MySQL root password |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` | AWS credentials (S3 access) |
| `AZURE_STORAGE_CONNECTION_STRING` | Azure Blob connection string |
| `KUBECONFIG_LOCAL` | Local cluster kubeconfig |
| `EKS_CLUSTER_NAME` | EKS cluster name |
| `AZURE_CREDENTIALS` | Azure service principal JSON |
| `AKS_CLUSTER_NAME` / `AKS_RESOURCE_GROUP` | AKS cluster info |

### user-service repo

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | DockerHub credentials |
| `DB_PASSWORD` | user-service MySQL root password |
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
| `DB_PASSWORD_GATEWAY` | api-gateway MySQL root password |
| `DB_PASSWORD_ABONNEMENT` / `MYSQL_ROOT_PASSWORD` | abonnement DB passwords |
| `DB_PASSWORD_USER_SERVICE` | user-service MySQL root password |
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
- [ ] Kafka external access for local monitoring/debugging
- [x] notification-service (consumes Kafka events — email via SMTP)
- [ ] pdf-service (PDF access control based on subscription plan — S3/Azure Blob)
- [ ] Prometheus + Grafana observability stack
- [x] Redis (cache, sessions, queue, token blacklist for api-gateway)
