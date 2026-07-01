# kafka

Kubernetes manifests for deploying Apache Kafka in KRaft mode (no Zookeeper) as the event bus for the microservices platform.

## Description

Kafka serves as the asynchronous messaging backbone connecting the microservices. It runs in KRaft mode — a single-node broker that also acts as its own controller, eliminating the need for a separate Zookeeper ensemble.

All services publish and consume events through Kafka. Topics are auto-created on first produce. The broker is deployed as a Kubernetes Deployment with a PersistentVolumeClaim for data durability.

### Key design decisions
- **KRaft mode (no Zookeeper)** — simpler deployment, fewer moving parts, single pod
- **Auto-create topics** — services don't need to pre-create topics; they're created on first message
- **ClusterIP only** — never exposed outside the cluster; network policy restricts which pods can connect
- **2Gi PVC** — data persists across pod restarts; Kafka retains messages for consumer lag recovery
- **Low resource limits** — 512Mi-1Gi memory, 200m-500m CPU; sufficient for development and small production

## Architecture

```
┌──────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│   api-gateway    │     │     abonnement       │     │    user-service      │
│   (producer)     │     │     (producer)       │     │ (producer + consumer)│
└────────┬─────────┘     └──────────┬───────────┘     └──────────┬───────────┘
         │                          │                             │
         ▼                          ▼                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Kafka (KRaft mode)                                    │
│                        ClusterIP :9092                                       │
│                                                                             │
│  Topics:                                                                    │
│    • user.registered         → user-service creates profile                 │
│    • user.login              → (logged)                                     │
│    • subscription.changed    → user-service logs activity                   │
│                              → notification-service sends email             │
│    • payment.succeeded       → notification-service sends receipt           │
│    • payment.failed          → notification-service sends alert             │
│    • user.profile_updated    → (future consumers)                           │
│    • user.preferences_updated → (future consumers)                          │
└─────────────────────────────────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
┌──────────────────────┐     ┌──────────────────────┐
│ notification-service │     │    user-service      │
│    (consumer)        │     │    (consumer)        │
└──────────────────────┘     └──────────────────────┘
```

## Directory Structure

```
kafka/
└── k8s/
    └── local/
        ├── kafka.yaml            # PVC + Deployment + Service
        └── network-policy.yaml   # Only authorized pods can access port 9092
```

## Kafka Configuration

| Setting | Value | Purpose |
|---|---|---|
| Image | `apache/kafka:3.7.0` | Latest stable with KRaft support |
| Mode | KRaft (broker + controller) | No Zookeeper needed |
| Listeners | `PLAINTEXT://:9092` (broker), `CONTROLLER://:9093` | Internal only |
| Advertised listeners | `kafka.default.svc.cluster.local:9092` | K8s DNS service name |
| Auto-create topics | `true` | Topics created on first produce |
| Replication factor | `1` | Single-node (no redundancy) |
| Log directory | `/var/lib/kafka/data` | Mounted PVC |
| Heap | `-Xmx512M -Xms256M` | Conservative memory usage |

## Network Policy

Only these pods are allowed to connect to Kafka on port 9092:
- `api-gateway` (producer)
- `abonnement` (producer)
- `user-service` (producer + consumer)
- `notification-service` (consumer)

All other pods are denied access.

## Topics

| Topic | Producers | Consumers |
|---|---|---|
| `user.registered` | api-gateway | user-service |
| `user.login` | api-gateway | — |
| `subscription.changed` | abonnement | user-service, notification-service |
| `payment.succeeded` | abonnement | notification-service |
| `payment.failed` | abonnement | notification-service |
| `user.profile_updated` | user-service | — (future) |
| `user.preferences_updated` | user-service | — (future) |

## Deployment

Kafka is deployed automatically by `deploy-local.sh`:

```bash
kubectl apply -f kafka/k8s/local/kafka.yaml
kubectl apply -f kafka/k8s/local/network-policy.yaml
kubectl rollout status deployment/kafka --timeout=120s
```

## Debugging

```bash
# Check Kafka pod status
kubectl get pods -l app=kafka

# View Kafka logs
kubectl logs -l app=kafka --tail=30

# List topics (exec into the pod)
kubectl exec -it deployment/kafka -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list

# Describe a topic
kubectl exec -it deployment/kafka -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --describe --topic user.registered

# Consume messages from a topic (for debugging)
kubectl exec -it deployment/kafka -- /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 --topic subscription.changed --from-beginning --max-messages 5
```

## Resource Limits

| Resource | Request | Limit |
|---|---|---|
| CPU | 200m | 500m |
| Memory | 512Mi | 1Gi |
| Storage (PVC) | 2Gi | — |
