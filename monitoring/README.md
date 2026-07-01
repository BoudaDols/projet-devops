# monitoring

Kubernetes manifests for the observability stack: Prometheus for metrics collection and Grafana for visualization, plus exporters for MySQL and Redis.

## Description

The monitoring stack runs in a dedicated `monitoring` namespace and collects metrics from all services in the platform. Prometheus scrapes targets every 15 seconds and retains data for 7 days. Grafana starts with pre-provisioned dashboards — no manual configuration needed.

### Key design decisions
- **Separate namespace** — monitoring pods isolated from application pods
- **Prometheus RBAC** — ServiceAccount with cluster-wide read access to discover pods
- **Auto-discovery** — any pod with `prometheus.io/scrape: "true"` annotation is scraped automatically
- **Grafana anonymous admin** — no login for local dev; dashboards load immediately
- **Provisioned datasource + dashboards** — everything configured via ConfigMaps, zero UI clicks
- **No persistence for Prometheus** — uses `emptyDir`; data lost on restart (acceptable for local dev)
- **Exporters in monitoring namespace** — reach across to default namespace services via K8s DNS

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    monitoring namespace                       │
│                                                             │
│  ┌──────────────┐    ┌──────────────────┐    ┌───────────┐ │
│  │  Prometheus  │◄───│ kube-state-metrics│    │  Grafana  │ │
│  │  v2.53.0     │    │  v2.13.0         │    │  v11.1.0  │ │
│  │  :9090       │    │  :8080           │    │  :3000    │ │
│  └──────┬───────┘    └──────────────────┘    └─────┬─────┘ │
│         │                                          │        │
│         │  scrapes every 15s                       │ reads  │
│         ▼                                          ▼        │
│  ┌──────────────┐    ┌──────────────────┐                   │
│  │mysql-exporter│    │ redis-exporter   │                   │
│  │  v0.15.1     │    │  v1.66.0         │                   │
│  │  :9104       │    │  :9121           │                   │
│  └──────┬───────┘    └──────────┬───────┘                   │
└─────────┼───────────────────────┼───────────────────────────┘
          │                       │
          ▼ (default namespace)   ▼ (default namespace)
   api-gateway-mysql         redis + pdf-service-redis
```

## Directory Structure

```
monitoring/
└── k8s/
    └── local/
        ├── namespace.yaml                  # Creates 'monitoring' namespace
        ├── prometheus/
        │   ├── rbac.yaml                   # ServiceAccount + ClusterRole + Binding
        │   ├── configmap.yaml              # prometheus.yml scrape config
        │   ├── deployment.yaml             # Prometheus v2.53.0
        │   └── service.yaml                # ClusterIP :9090
        ├── kube-state-metrics/
        │   ├── rbac.yaml                   # ServiceAccount + ClusterRole + Binding
        │   ├── deployment.yaml             # kube-state-metrics v2.13.0
        │   └── service.yaml                # ClusterIP :8080/:8081
        ├── mysql-exporter/
        │   ├── deployment.yaml             # mysqld-exporter v0.15.1
        │   └── service.yaml                # ClusterIP :9104
        ├── redis-exporter/
        │   ├── deployment.yaml             # redis_exporter v1.66.0
        │   └── service.yaml                # ClusterIP :9121
        └── grafana/
            ├── datasource.yaml             # ConfigMap: auto-provisions Prometheus
            ├── dashboards.yaml             # ConfigMap: dashboard provider config
            ├── dashboard-k8s.yaml          # ConfigMap: Kubernetes cluster dashboard JSON
            ├── dashboard-mysql.yaml        # ConfigMap: MySQL metrics dashboard JSON
            ├── dashboard-redis.yaml        # ConfigMap: Redis metrics dashboard JSON
            ├── deployment.yaml             # Grafana v11.1.0 with volume mounts
            └── service.yaml                # ClusterIP :3000
```

## Components

| Component | Version | Port | Purpose |
|---|---|---|---|
| Prometheus | v2.53.0 | 9090 | Metrics collection + storage (7-day retention) |
| Grafana | v11.1.0 | 3000 | Dashboard visualization (anonymous admin, no login) |
| kube-state-metrics | v2.13.0 | 8080 | Kubernetes object metrics (pods, deployments, nodes) |
| mysqld-exporter | v0.15.1 | 9104 | MySQL metrics (queries, connections, InnoDB) |
| redis_exporter | v1.66.0 | 9121 | Redis metrics (memory, hit rate, commands/s) |

## Prometheus Scrape Targets

| Job | Target | Metrics |
|---|---|---|
| `prometheus` | `localhost:9090` | Prometheus self-metrics |
| `kube-state-metrics` | `kube-state-metrics:8080` | Pod/deployment/node status |
| `redis` | `redis-exporter:9121` | Both Redis instances (api-gateway + pdf-service) |
| `mysql` | `mysql-exporter:9104` | api-gateway MySQL |
| `kubernetes-pods` | Auto-discovered | Any pod with `prometheus.io/scrape: "true"` annotation |

## Grafana Dashboards

| Dashboard | Folder | Panels |
|---|---|---|
| Kubernetes Cluster Overview | Infrastructure | Pods running/not ready, deployment replicas, container restarts, CPU/memory usage |
| MySQL Overview | Databases | Up status, connections, slow queries, QPS, CRUD breakdown, InnoDB buffer pool |
| Redis Overview | Databases | Up status, connected clients, memory, hit rate, commands/s, keys by DB |

All dashboards are pre-loaded via Grafana provisioning (ConfigMaps mounted as volumes). No manual import needed.

## Deployment

Deployed automatically by `deploy-local.sh`:

```bash
kubectl apply -f monitoring/k8s/local/namespace.yaml
kubectl apply -f monitoring/k8s/local/prometheus/
kubectl apply -f monitoring/k8s/local/kube-state-metrics/
kubectl apply -f monitoring/k8s/local/mysql-exporter/
kubectl apply -f monitoring/k8s/local/redis-exporter/
kubectl apply -f monitoring/k8s/local/grafana/
```

## Access

```bash
# Prometheus UI
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# → http://localhost:9090

# Grafana UI (no login required)
kubectl port-forward svc/grafana 3000:3000 -n monitoring
# → http://localhost:3000
```

## Useful PromQL Queries

```promql
# Pods not running in default namespace
sum(kube_pod_status_phase{phase!="Running", phase!="Succeeded", namespace="default"})

# Container restarts in last hour
sum(increase(kube_pod_container_status_restarts_total{namespace="default"}[1h]))

# MySQL queries per second
rate(mysql_global_status_queries[5m])

# Redis hit rate
sum(redis_keyspace_hits_total) / (sum(redis_keyspace_hits_total) + sum(redis_keyspace_misses_total))

# Redis memory usage
redis_memory_used_bytes
```

## Resource Limits

| Component | CPU request/limit | Memory request/limit |
|---|---|---|
| Prometheus | 100m / 500m | 256Mi / 512Mi |
| Grafana | 100m / 250m | 128Mi / 256Mi |
| kube-state-metrics | 50m / 100m | 64Mi / 128Mi |
| mysql-exporter | 25m / 50m | 32Mi / 64Mi |
| redis-exporter | 25m / 50m | 32Mi / 64Mi |
