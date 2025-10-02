#!/bin/bash
set -e

echo "Pulling latest changes..."
git pull origin main

echo "Cleaning up previous deployment..."
helm uninstall infrastructure -n default 2>/dev/null || true
kubectl delete jobs -n default --all
kubectl delete secrets -n default -l app.kubernetes.io/instance=infrastructure

echo "Rebuilding chart dependencies..."
helm dependency build charts/infrastructure/postgresql/
helm dependency build charts/infrastructure/redis/
helm dependency build charts/infrastructure/

echo "Deploying infrastructure..."
helm install infrastructure ./charts/infrastructure \
  --namespace default \
  --create-namespace \
  --wait \
  --timeout 15m

echo ""
echo "=== Infrastructure Pods ==="
kubectl get pods -n default -l app.kubernetes.io/instance=infrastructure

echo ""
echo "=== Init Jobs ==="
kubectl get jobs -n default

echo ""
echo "=== PostgreSQL Init Logs ==="
kubectl logs -n default -l role=init --tail=100 2>/dev/null || echo "No init job yet"

echo ""
echo "=== Redis ACL Init Logs ==="
kubectl logs -n default -l role=init-acl --tail=100 2>/dev/null || echo "No ACL init job yet"

echo ""
echo "=== Secrets Created ==="
kubectl get secrets -n default | grep -E "NAME|postgres|redis"
