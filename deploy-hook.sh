#!/bin/bash
set -e

echo "========================================"
echo "DEPLOY HOOK - Triggered by GitHub Webhook"
echo "========================================"

echo ""
echo "=== 1. Pull latest changes ==="
git pull origin main

echo ""
echo "=== 2. Apply Helm charts ==="
helm upgrade --install infrastructure charts/infrastructure \
  --namespace default \
  --create-namespace \
  --wait

echo ""
echo "=== 3. Trigger ArgoCD sync ==="
kubectl patch application -n argocd core-pipeline-dev -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type=merge || true
kubectl patch application -n argocd core-pipeline-prod -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type=merge || true

echo ""
echo "=== 4. Wait for deployments ==="
kubectl rollout status deployment/core-pipeline-dev -n dev-core --timeout=300s || true
kubectl rollout status deployment/core-pipeline-prod -n prod-core --timeout=300s || true

echo ""
echo "Deploy complete! Check status:"
echo "  kubectl get pods -n dev-core"
echo "  kubectl get pods -n prod-core"
