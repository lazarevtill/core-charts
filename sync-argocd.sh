#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔄 ArgoCD State Cleanup & Sync Script"
echo "======================================"
echo "Using KUBECONFIG: $KUBECONFIG"
echo ""

# Pull latest code
echo ""
echo "0️⃣ Pulling latest code from GitHub..."
git pull origin main
echo "   ✅ Code updated"

# Delete landing page application (migrated to GitHub Pages)
echo ""
echo "1️⃣ Deleting landing page application..."
kubectl delete application landing-page -n argocd --ignore-not-found=true
echo "   ✅ Landing page application deleted"

# Delete any old infrastructure resources from k8s/infrastructure
echo ""
echo "2️⃣ Cleaning old raw manifest resources..."
kubectl delete cluster infrastructure-postgres -n infrastructure --ignore-not-found=true 2>/dev/null || true
kubectl delete kafka infrastructure-kafka -n infrastructure --ignore-not-found=true 2>/dev/null || true
kubectl delete deployment infrastructure-redis -n infrastructure --ignore-not-found=true 2>/dev/null || true
kubectl delete service infrastructure-redis -n infrastructure --ignore-not-found=true 2>/dev/null || true
kubectl delete configmap redis-config -n infrastructure --ignore-not-found=true 2>/dev/null || true
echo "   ✅ Old resources cleaned"

# CRITICAL: Apply updated ArgoCD applications with correct Helm chart paths
echo ""
echo "3️⃣ Applying updated ArgoCD applications (Helm chart paths)..."
kubectl apply -f argocd-apps/infrastructure.yaml
kubectl apply -f argocd-apps/core-pipeline-dev.yaml
kubectl apply -f argocd-apps/core-pipeline-prod.yaml
echo "   ✅ ArgoCD applications updated (now pointing to charts/ not k8s/)"

# Wait a moment for ArgoCD to detect changes
echo ""
echo "4️⃣ Waiting for ArgoCD to detect changes..."
sleep 5

# Trigger hard refresh and sync for infrastructure
echo ""
echo "5️⃣ Syncing infrastructure (Bitnami Helm charts)..."
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD","prune":true,"syncOptions":["CreateNamespace=true"]}}}'
echo "   ✅ Infrastructure sync triggered"

# Wait for infrastructure to sync
echo ""
echo "6️⃣ Waiting for infrastructure sync (this may take 2-3 minutes)..."
sleep 10

# Sync applications
echo ""
echo "7️⃣ Syncing core-pipeline-dev..."
kubectl patch application core-pipeline-dev -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'

echo ""
echo "8️⃣ Syncing core-pipeline-prod..."
kubectl patch application core-pipeline-prod -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'

echo ""
echo "✅ DONE!"
echo ""
echo "📊 Check ArgoCD UI: https://argo.theedgestory.org"
echo ""
echo "🔍 Monitor sync status:"
echo "   kubectl get applications -n argocd"
echo ""
echo "Expected state:"
echo "   - infrastructure:      Synced + Healthy (PostgreSQL, Redis, Kafka from Bitnami)"
echo "   - core-pipeline-dev:   Synced + Healthy"
echo "   - core-pipeline-prod:  Synced + Healthy"
echo "   - landing-page:        DELETED (migrated to GitHub Pages)"
