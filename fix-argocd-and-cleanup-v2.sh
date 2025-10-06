#!/bin/bash
set -e

echo "🔧 ArgoCD Fix & Infrastructure Cleanup v2"
echo "=========================================="
echo ""

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "1️⃣  Checking if argocd-cm exists..."
if kubectl get configmap argocd-cm -n argocd &>/dev/null; then
  echo "   ✅ argocd-cm exists"
else
  echo "   ⚠️  argocd-cm does not exist, creating it..."
  kubectl create configmap argocd-cm -n argocd
  echo "   ✅ argocd-cm created"
fi

echo ""
echo "2️⃣  Adding navigation links to ArgoCD UI..."
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
echo "3️⃣  Restarting ArgoCD server to pick up changes..."
kubectl rollout restart deployment argocd-server -n argocd
echo "   ✅ ArgoCD server restarting"

echo ""
echo "4️⃣  Deleting old Bitnami Kafka StatefulSets..."
kubectl delete statefulset infrastructure-kafka-controller -n infrastructure --ignore-not-found=true
echo "   ✅ Kafka StatefulSets deleted"

echo ""
echo "5️⃣  Deleting duplicate/old ingresses..."
kubectl delete ingress grafana-dev -n monitoring --ignore-not-found=true
echo "   Deleted: grafana-dev"

# Delete ALL ACME HTTP solver ingresses (they're temporary and will be recreated if needed)
kubectl get ingress -A -o json | jq -r '.items[] | select(.metadata.name | startswith("cm-acme-http-solver-")) | "\(.metadata.namespace) \(.metadata.name)"' | while read ns name; do
  echo "   Deleting ACME solver: $ns/$name"
  kubectl delete ingress "$name" -n "$ns" --ignore-not-found=true
done
echo "   ✅ Duplicate ingresses deleted"

echo ""
echo "6️⃣  Triggering ArgoCD sync for infrastructure..."
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'
echo "   ✅ Sync triggered"

echo ""
echo "7️⃣  Waiting 30 seconds for infrastructure to sync..."
sleep 30

echo ""
echo "8️⃣  Checking infrastructure pods..."
echo ""
kubectl get pods -n infrastructure --no-headers | grep -v "kafka-controller" | awk '{print "   " $1 " - " $3}' || echo "   ✅ All clean"

echo ""
echo "9️⃣  Checking ArgoCD deployment status..."
kubectl rollout status deployment argocd-server -n argocd --timeout=60s

echo ""
echo "🔟  Final status check..."
echo ""
echo "Infrastructure pods:"
kubectl get pods -n infrastructure | grep -E "NAME|postgresql|redis|kafka-ui"

echo ""
echo "Clean ingresses (no duplicates):"
kubectl get ingress -A | grep -E "NAME|argo.theedgestory.org|grafana.theedgestory.org|prometheus.theedgestory.org|kafka.theedgestory.org|status.theedgestory.org" | grep -v "grafana-dev"

echo ""
echo "======================================="
echo "✅ FIX COMPLETE!"
echo ""
echo "Next steps:"
echo "  1. Wait 2-3 minutes for TLS certificates to be issued"
echo "  2. Visit: https://argo.theedgestory.org"
echo "  3. Login with Google OAuth2 (dcversus@gmail.com)"
echo "  4. You should see navigation links in top menu"
echo ""
echo "Monitor certificates:"
echo "  watch 'kubectl get certificates -A | grep -v cloudflare'"
