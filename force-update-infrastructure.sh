#!/bin/bash
set -e

echo "🔧 Force Update Infrastructure App to Helm Chart"
echo "================================================"

# Pull latest code
echo ""
echo "1️⃣ Pulling latest code..."
git pull origin main
echo "   ✅ Code updated"

# Delete the infrastructure application completely
echo ""
echo "2️⃣ Deleting old infrastructure application..."
kubectl delete application infrastructure -n argocd --ignore-not-found=true
echo "   ✅ Old app deleted"

# Wait for deletion to complete
echo ""
echo "3️⃣ Waiting for deletion to complete..."
sleep 3

# Apply the new infrastructure application with Helm chart path
echo ""
echo "4️⃣ Creating new infrastructure application (Helm chart)..."
kubectl apply -f argocd-apps/infrastructure.yaml
echo "   ✅ New app created with path: charts/infrastructure"

# Wait for ArgoCD to recognize the app
echo ""
echo "5️⃣ Waiting for ArgoCD to initialize app..."
sleep 5

# Trigger hard refresh
echo ""
echo "6️⃣ Triggering hard refresh..."
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
echo "   ✅ Hard refresh triggered"

# Trigger sync
echo ""
echo "7️⃣ Triggering sync (Bitnami Helm charts will be fetched)..."
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}'
echo "   ✅ Sync triggered"

echo ""
echo "✅ DONE!"
echo ""
echo "📊 Check ArgoCD UI: https://argo.theedgestory.org/applications/argocd/infrastructure"
echo ""
echo "🔍 Monitor status:"
echo "   kubectl get application infrastructure -n argocd -o jsonpath='{.spec.source.path}'"
echo "   (should show: charts/infrastructure)"
echo ""
echo "Expected behavior:"
echo "   - ArgoCD fetches remote Bitnami charts (PostgreSQL 16.4.0, Redis 20.6.0, Kafka 31.0.0)"
echo "   - Deploys infrastructure in sync-wave 1"
echo "   - Status changes to: Synced + Healthy"
