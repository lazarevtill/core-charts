#!/bin/bash
set -e

echo "🔧 Applying Working Configuration"
echo "=================================="
echo ""

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "1️⃣  Applying ArgoCD ingress..."
kubectl apply -f argocd-config/argocd-ingress.yaml
echo "   ✅ ArgoCD ingress applied"

echo ""
echo "2️⃣  Checking if argocd-cm exists..."
if kubectl get configmap argocd-cm -n argocd &>/dev/null; then
  echo "   ✅ argocd-cm exists"
else
  echo "   ⚠️  argocd-cm does not exist, creating it..."
  kubectl create configmap argocd-cm -n argocd
  echo "   ✅ argocd-cm created"
fi

echo ""
echo "3️⃣  Adding navigation links to ArgoCD..."
kubectl patch configmap argocd-cm -n argocd --type merge --patch '
data:
  ui.externalLinks: |
    - title: "🏠 The Edge Story"
      url: "https://theedgestory.org"
    - title: "✅ Status Page"
      url: "https://status.theedgestory.org"
    - title: "📊 Grafana"
      url: "https://grafana.theedgestory.org"
    - title: "📈 Prometheus"
      url: "https://prometheus.theedgestory.org"
    - title: "📨 Kafka UI"
      url: "https://kafka.theedgestory.org"
    - title: "💾 MinIO Console"
      url: "https://s3-admin.theedgestory.org"
    - title: "🚀 Dev Pipeline"
      url: "https://core-pipeline.dev.theedgestory.org/api-docs"
    - title: "✨ Prod Pipeline"
      url: "https://core-pipeline.theedgestory.org/api-docs"
'
echo "   ✅ Navigation links added"

echo ""
echo "4️⃣  Restarting ArgoCD server..."
kubectl rollout restart deployment argocd-server -n argocd
echo "   ✅ ArgoCD server restarting"

echo ""
echo "5️⃣  Triggering ArgoCD sync for infrastructure..."
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'
echo "   ✅ Sync triggered"

echo ""
echo "6️⃣  Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment argocd-server -n argocd --timeout=120s
echo "   ✅ ArgoCD server ready"

echo ""
echo "7️⃣  Checking infrastructure deployment..."
kubectl get pods -n infrastructure | head -10

echo ""
echo "8️⃣  Checking all ingresses..."
kubectl get ingress -A | grep theedgestory.org

echo ""
echo "9️⃣  Checking certificates..."
kubectl get certificates -A | grep -E "NAME|argocd|grafana|prometheus|status"

echo ""
echo "=================================="
echo "✅ CONFIGURATION APPLIED!"
echo ""
echo "Service URLs:"
echo "  - ArgoCD: https://argo.theedgestory.org"
echo "  - Grafana: https://grafana.theedgestory.org"
echo "  - Prometheus: https://prometheus.theedgestory.org"
echo "  - Status Page: https://status.theedgestory.org"
echo "  - Kafka UI: https://kafka.theedgestory.org"
echo ""
echo "Note: TLS certificates may take 2-3 minutes to be issued"
echo "Monitor with: kubectl get certificates -A"
echo ""
