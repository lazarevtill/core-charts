#!/bin/bash
set -e

echo "🔧 ArgoCD Fix & Infrastructure Cleanup"
echo "======================================="
echo ""

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "1️⃣  Deleting conflicting ArgoCD ConfigMaps from infrastructure chart..."
kubectl delete configmap argocd-cm argocd-rbac-cm -n argocd --ignore-not-found=true
echo "   ✅ Old ConfigMaps deleted (if they existed)"

echo ""
echo "2️⃣  Waiting 5 seconds for ArgoCD to recreate default ConfigMaps..."
sleep 5

echo ""
echo "3️⃣  Adding navigation links to ArgoCD UI..."
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
echo "4️⃣  Restarting ArgoCD server to pick up changes..."
kubectl rollout restart deployment argocd-server -n argocd
echo "   ✅ ArgoCD server restarting"

echo ""
echo "5️⃣  Deleting old Bitnami Kafka StatefulSets..."
kubectl delete statefulset infrastructure-kafka-controller -n infrastructure --ignore-not-found=true
echo "   ✅ Kafka StatefulSets deleted"

echo ""
echo "6️⃣  Deleting duplicate/old ingresses..."
kubectl delete ingress grafana-dev -n monitoring --ignore-not-found=true
kubectl delete ingress cm-acme-http-solver-dp9bx -n infrastructure --ignore-not-found=true
kubectl delete ingress cm-acme-http-solver-4gwzw -n minio --ignore-not-found=true
kubectl delete ingress cm-acme-http-solver-gd6sd -n minio --ignore-not-found=true
kubectl delete ingress cm-acme-http-solver-npdjn -n minio --ignore-not-found=true
kubectl delete ingress cm-acme-http-solver-vjwqk -n argocd --ignore-not-found=true
kubectl delete ingress cm-acme-http-solver-4zw29 -n monitoring --ignore-not-found=true
kubectl delete ingress cm-acme-http-solver-fdfnr -n monitoring --ignore-not-found=true
kubectl delete ingress cm-acme-http-solver-6kdrj -n infrastructure --ignore-not-found=true
echo "   ✅ Duplicate ingresses deleted"

echo ""
echo "7️⃣  Triggering ArgoCD sync for infrastructure..."
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'
echo "   ✅ Sync triggered"

echo ""
echo "8️⃣  Waiting 30 seconds for infrastructure to sync..."
sleep 30

echo ""
echo "9️⃣  Checking infrastructure pods..."
kubectl get pods -n infrastructure | grep -v "kafka-controller" || echo "   ✅ No old Kafka controller pods"

echo ""
echo "🔟  Checking ArgoCD deployment..."
kubectl rollout status deployment argocd-server -n argocd --timeout=60s

echo ""
echo "======================================="
echo "✅ FIX COMPLETE!"
echo ""
echo "Next steps:"
echo "  1. Wait 1-2 minutes for ArgoCD to fully restart"
echo "  2. Visit: https://argo.theedgestory.org"
echo "  3. Login with Google OAuth2 (dcversus@gmail.com)"
echo "  4. You should see navigation links in top menu"
echo ""
echo "Check status:"
echo "  kubectl get pods -n infrastructure"
echo "  kubectl get ingress -A | grep theedgestory.org"
echo "  kubectl get certificates -A"
