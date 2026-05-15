#!/bin/bash
set -e

echo "==> Building Docker images..."
docker build -t abonnement:latest ./abonnement
docker build -t api-gateway:latest ./api-gateway
docker build -t user-service:latest ./user-service

echo "==> Deploying Kafka infrastructure..."
kubectl apply -f kafka/k8s/local/kafka.yaml
kubectl apply -f kafka/k8s/local/network-policy.yaml

echo "==> Waiting for Zookeeper to be ready..."
kubectl rollout status deployment/zookeeper --timeout=120s

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

echo "==> Waiting for api-gateway MySQL to be ready..."
kubectl rollout status deployment/api-gateway-mysql --timeout=120s

echo "==> Deploying api-gateway..."
kubectl apply -f api-gateway/k8s/local/deployment.yaml

echo "==> Running api-gateway migrations..."
kubectl delete pod migrations --ignore-not-found
kubectl apply -f api-gateway/k8s/migrations.yaml
kubectl wait --for=condition=complete pod/migrations --timeout=120s

echo "==> Deploying user-service dependencies..."
kubectl apply -f user-service/k8s/local/secret.yaml
kubectl apply -f user-service/k8s/local/configmap.yaml
kubectl apply -f user-service/k8s/local/mysql.yaml

echo "==> Waiting for user-service MySQL to be ready..."
kubectl rollout status deployment/user-service-mysql --timeout=120s

echo "==> Deploying user-service..."
kubectl apply -f user-service/k8s/local/deployment.yaml
kubectl apply -f user-service/k8s/local/network-policy.yaml

echo ""
echo "==> Done. Gateway available at http://localhost:30080"
