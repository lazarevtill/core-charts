#!/bin/bash
set -e

echo "🚀 EMERGENCY DEPLOYMENT - Apply All Configuration"
echo "=================================================="
echo ""

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "1️⃣  Checking prerequisites..."
echo "   ArgoCD pods:"
kubectl get pods -n argocd | grep argocd-server || echo "   ⚠️  ArgoCD not running!"
echo ""
echo "   nginx-ingress:"
kubectl get pods -n kube-system | grep ingress || echo "   ⚠️  nginx-ingress not running!"
echo ""

echo "2️⃣  Applying ArgoCD ingress (critical for access)..."
kubectl apply -f argocd-config/argocd-ingress.yaml
echo "   ✅ ArgoCD ingress applied"
echo ""

echo "3️⃣  Creating/updating argocd-cm with navigation links..."
kubectl create configmap argocd-cm -n argocd --dry-run=client -o yaml | kubectl apply -f -
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

echo "5️⃣  Waiting for ArgoCD to be ready (30 seconds)..."
sleep 30
kubectl rollout status deployment argocd-server -n argocd --timeout=60s
echo ""

echo "6️⃣  Checking ingress status..."
kubectl get ingress argocd-server -n argocd
echo ""

echo "7️⃣  Checking certificate status..."
kubectl get certificate -n argocd | grep argocd || echo "   ℹ️  No certificate yet (will be created automatically)"
echo ""

echo "8️⃣  Testing ArgoCD service internally..."
echo "   Running curl test..."
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never -- \
  curl -I -H "Host: argo.theedgestory.org" http://argocd-server.argocd.svc.cluster.local 2>&1 | head -5 || true
echo ""

echo "9️⃣  Checking DNS resolution..."
echo "   Checking argo.theedgestory.org:"
dig +short argo.theedgestory.org | head -3
echo ""

echo "🔟  Final status check..."
echo ""
echo "Pods:"
kubectl get pods -n argocd | grep argocd-server
echo ""
echo "Ingress:"
kubectl get ingress -n argocd
echo ""
echo "Service:"
kubectl get svc -n argocd | grep argocd-server
echo ""

echo "=================================================="
echo "✅ DEPLOYMENT COMPLETE"
echo ""
echo "Next steps:"
echo ""
echo "1. If using Cloudflare proxy (orange cloud):"
echo "   - DNS must point directly to 46.62.223.198 (gray cloud)"
echo "   - OR setup Cloudflare Tunnel: bash setup-cloudflare-tunnel.sh"
echo ""
echo "2. Wait 2-3 minutes for TLS certificate"
echo "   kubectl get certificate -n argocd -w"
echo ""
echo "3. Test ArgoCD access:"
echo "   curl -I https://argo.theedgestory.org"
echo ""
echo "4. If still 404, check nginx-ingress logs:"
echo "   kubectl logs -n kube-system -l app.kubernetes.io/name=ingress-nginx --tail=50"
echo ""
