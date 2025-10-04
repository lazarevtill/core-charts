#!/bin/bash
# ArgoCD-based deployment handler - GitOps workflow
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "🚀 DEPLOY HOOK - ArgoCD GitOps Handler"
echo "========================================"
echo "Timestamp: $(date)"
echo "Working directory: $(pwd)"
echo ""

# Helper function to sync ArgoCD application
sync_app() {
  local app_name=$1
  local timeout=${2:-300}

  echo "Syncing ArgoCD application: $app_name"
  kubectl patch application "$app_name" -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"webhook"},"sync":{"revision":"HEAD"}}}'

  echo "Waiting for $app_name to sync (timeout: ${timeout}s)..."
  kubectl wait --for=condition=SyncStatusCode=Synced application/"$app_name" -n argocd --timeout="${timeout}s" || echo "⚠️  $app_name sync timeout"
  kubectl wait --for=condition=HealthStatusCode=Healthy application/"$app_name" -n argocd --timeout="${timeout}s" || echo "⚠️  $app_name health check timeout"
}

# 1. Pull latest changes (this triggers ArgoCD to detect new commits)
echo "=== 1. Pull latest changes from GitHub ==="
git pull origin main
echo "✅ Code updated to latest commit: $(git rev-parse --short HEAD)"
echo ""

# 2. ArgoCD will fetch dependencies from remote registries
echo "=== 2. Using remote Helm charts (Pure GitOps) ==="
echo "ArgoCD will fetch charts from Bitnami registry automatically"
echo "✅ No local dependency build needed"
echo ""

# 3. Apply ArgoCD application manifests
echo "=== 3. Apply ArgoCD application manifests ==="
kubectl apply -f argocd-apps/infrastructure.yaml
kubectl apply -f argocd-apps/core-pipeline-dev.yaml
kubectl apply -f argocd-apps/core-pipeline-prod.yaml
kubectl apply -f argocd-apps/prometheus.yaml
kubectl apply -f argocd-apps/grafana.yaml
kubectl apply -f argocd-apps/loki.yaml
kubectl apply -f argocd-apps/tempo.yaml
kubectl apply -f argocd-apps/kafka-ui.yaml || echo "⚠️  Kafka UI app not found (optional)"
echo "✅ ArgoCD applications configured"
echo ""

# 4. Sync shared infrastructure
echo "=== 4. Sync shared infrastructure via ArgoCD ==="
sync_app "infrastructure" 600
echo "✅ Shared infrastructure synced"
echo ""

# 5. Sync monitoring applications
echo "=== 5. Sync monitoring via ArgoCD ==="
sync_app "prometheus" 300
sync_app "grafana" 300
sync_app "loki" 300
sync_app "tempo" 300
echo "✅ Monitoring synced"
echo ""

# 6. Sync application deployments
echo "=== 6. Sync applications via ArgoCD ==="
sync_app "core-pipeline-dev" 300
sync_app "core-pipeline-prod" 300
echo "✅ Applications synced"
echo ""

# 7. Final status
echo "========================================"
echo "✅ DEPLOYMENT COMPLETE - ArgoCD GitOps"
echo "========================================"
echo ""
echo "ArgoCD Applications:"
kubectl get applications -n argocd
echo ""
echo "Shared Infrastructure (namespace: infrastructure):"
kubectl get pods -n infrastructure 2>/dev/null | head -10 || echo "  (namespace not present or empty)"
echo ""
echo "Application namespaces:"
echo "  - dev-core:"
kubectl get pods -n dev-core 2>/dev/null || echo "    (namespace not present or empty)"
echo "  - prod-core:"
kubectl get pods -n prod-core 2>/dev/null || echo "    (namespace not present or empty)"
echo ""
echo "Monitoring namespace:"
kubectl get pods -n monitoring 2>/dev/null | head -5 || echo "  (namespace not present or empty)"
echo ""
echo "Health checks:"
echo "  ArgoCD: https://argo.dev.theedgestory.org"
echo "  Dev:    https://core-pipeline.dev.theedgestory.org/health"
echo "  Prod:   https://core-pipeline.theedgestory.org/health"
echo ""
echo "Swagger docs:"
echo "  Dev:  https://core-pipeline.dev.theedgestory.org/api-docs"
echo "  Prod: https://core-pipeline.theedgestory.org/api-docs"
echo ""
echo "Monitoring:"
echo "  Grafana:    https://grafana.dev.theedgestory.org"
echo "  Prometheus: https://prometheus.dev.theedgestory.org"
echo ""
