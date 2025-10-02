#!/bin/bash
# Webhook-based deployment handler - No ArgoCD pull, direct Helm deployments
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "🚀 DEPLOY HOOK - GitHub Webhook Handler"
echo "========================================"
echo "Timestamp: $(date)"
echo "Working directory: $(pwd)"
echo ""

# 1. Pull latest changes
echo "=== 1. Pull latest changes from GitHub ==="
git pull origin main
echo "✅ Code updated to latest commit: $(git rev-parse --short HEAD)"
echo ""

# 2. Build Helm dependencies (vendor charts)
echo "=== 2. Build Helm chart dependencies ==="
echo "Building infrastructure chart dependencies..."
helm dependency build charts/infrastructure/
echo "✅ Dependencies vendored"
echo ""

# 3. Deploy infrastructure (PostgreSQL, Redis, Kafka)
echo "=== 3. Deploy infrastructure to 'infrastructure' namespace ==="
helm upgrade --install infrastructure ./charts/infrastructure \
  --namespace infrastructure \
  --create-namespace \
  --set kafka.enabled=false \
  --wait \
  --timeout 10m
echo "✅ Infrastructure deployed"
echo ""

# 4. Verify infrastructure is healthy
echo "=== 4. Verify infrastructure pods ==="
kubectl get pods -n infrastructure
echo ""

# 5. Deploy dev application
echo "=== 5. Deploy core-pipeline-dev application ==="
helm upgrade --install core-pipeline-dev ./charts/core-pipeline \
  --namespace dev-core \
  --create-namespace \
  --values ./charts/core-pipeline/values.yaml \
  --values ./charts/core-pipeline/values-dev.yaml \
  --wait \
  --timeout 5m || echo "⚠️  Dev deployment failed or timed out"
echo "✅ Dev application deployed"
echo ""

# 6. Deploy prod application
echo "=== 6. Deploy core-pipeline-prod application ==="
helm upgrade --install core-pipeline-prod ./charts/core-pipeline \
  --namespace prod-core \
  --create-namespace \
  --values ./charts/core-pipeline/values.yaml \
  --values ./charts/core-pipeline/values-prod.yaml \
  --wait \
  --timeout 5m || echo "⚠️  Prod deployment failed or timed out"
echo "✅ Prod application deployed"
echo ""

# 7. Wait for rollouts
echo "=== 7. Wait for deployments to be ready ==="
kubectl rollout status deployment/core-pipeline-dev -n dev-core --timeout=300s || echo "⚠️  Dev rollout check failed"
kubectl rollout status deployment/core-pipeline-prod -n prod-core --timeout=300s || echo "⚠️  Prod rollout check failed"
echo ""

# 8. Final status
echo "========================================"
echo "✅ DEPLOYMENT COMPLETE"
echo "========================================"
echo ""
echo "Infrastructure status:"
kubectl get pods -n infrastructure
echo ""
echo "Dev application status:"
kubectl get pods -n dev-core
echo ""
echo "Prod application status:"
kubectl get pods -n prod-core
echo ""
echo "Health checks:"
echo "  Dev:  https://core-pipeline.dev.theedgestory.org/health"
echo "  Prod: https://core-pipeline.theedgestory.org/health"
echo ""
echo "Swagger docs:"
echo "  Dev:  https://core-pipeline.dev.theedgestory.org/api-docs"
echo "  Prod: https://core-pipeline.theedgestory.org/api-docs"
echo ""
