#!/bin/bash
set -e

CONTROL_PLANE=$(docker ps -qf "name=desktop-control-plane")

echo "==> Building Docker images..."
docker build -t abonnement:latest ./abonnement
docker build -t api-gateway:latest ./api-gateway
docker build -t user-service:latest ./user-service
docker build -t notification-service:latest ./notification-service

echo "==> Loading images into Kubernetes containerd..."
docker save abonnement:latest | docker exec -i $CONTROL_PLANE ctr -n k8s.io images import -
docker save api-gateway:latest | docker exec -i $CONTROL_PLANE ctr -n k8s.io images import -
docker save user-service:latest | docker exec -i $CONTROL_PLANE ctr -n k8s.io images import -
docker save notification-service:latest | docker exec -i $CONTROL_PLANE ctr -n k8s.io images import -

echo "==> Deploying Kafka infrastructure..."
kubectl apply -f kafka/k8s/local/kafka.yaml
kubectl apply -f kafka/k8s/local/network-policy.yaml

echo "==> Waiting for Kafka to be ready..."
kubectl rollout status deployment/kafka --timeout=120s

echo "==> Deploying abonnement dependencies..."
kubectl apply -f abonnement/k8s/local/secret.yaml
kubectl apply -f abonnement/k8s/local/configmap.yaml
kubectl apply -f abonnement/k8s/local/mysql.yaml

echo "==> Waiting for abonnement MySQL to be ready..."
kubectl rollout status deployment/mysql --timeout=120s

echo "==> Deploying abonnement..."
kubectl apply -f abonnement/k8s/local/deployment.yaml
kubectl apply -f abonnement/k8s/local/service.yaml
kubectl apply -f abonnement/k8s/local/network-policy.yaml

echo "==> Deploying api-gateway dependencies..."
kubectl apply -f api-gateway/k8s/local/secret.yaml
kubectl apply -f api-gateway/k8s/configmap.yaml
kubectl apply -f api-gateway/k8s/mysql.yaml
kubectl apply -f api-gateway/k8s/local/redis.yaml

echo "==> Waiting for api-gateway MySQL to be ready..."
kubectl rollout status deployment/api-gateway-mysql --timeout=120s

echo "==> Waiting for Redis to be ready..."
kubectl rollout status deployment/redis --timeout=60s

echo "==> Deploying api-gateway..."
kubectl apply -f api-gateway/k8s/local/deployment.yaml

echo "==> Running api-gateway migrations..."
kubectl delete pod migrations --ignore-not-found
kubectl apply -f api-gateway/k8s/migrations.yaml
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/migrations --timeout=120s

echo "==> Deploying user-service dependencies..."
kubectl apply -f user-service/k8s/local/secret.yaml
kubectl apply -f user-service/k8s/local/configmap.yaml
kubectl apply -f user-service/k8s/local/mysql.yaml

echo "==> Waiting for user-service MySQL to be ready..."
kubectl rollout status deployment/user-service-mysql --timeout=120s

echo "==> Deploying user-service..."
kubectl apply -f user-service/k8s/local/deployment.yaml
kubectl apply -f user-service/k8s/local/network-policy.yaml

echo "==> Deploying notification-service..."
kubectl apply -f notification-service/k8s/local/secret.yaml
kubectl apply -f notification-service/k8s/local/configmap.yaml
kubectl apply -f notification-service/k8s/local/deployment.yaml
kubectl apply -f notification-service/k8s/local/service.yaml
kubectl apply -f notification-service/k8s/local/network-policy.yaml

echo ""
echo "==> Waiting for all deployments..."
kubectl rollout status deployment/abonnement --timeout=120s
kubectl rollout status deployment/api-gateway --timeout=120s
kubectl rollout status deployment/user-service --timeout=120s
kubectl rollout status deployment/notification-service --timeout=120s

echo ""
echo "==> Done. Access the gateway:"
echo "    kubectl port-forward svc/api-gateway-service 8080:80"
echo "    → http://localhost:8080"
