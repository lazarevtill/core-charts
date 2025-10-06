#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "⚠️  EMERGENCY: Disable OAuth2 on ALL Services"
echo "=============================================="
echo ""
echo "This will REMOVE OAuth2 authentication from all services"
echo "so you can access them immediately while we fix the certificate."
echo ""
echo "Services affected:"
echo "  - ArgoCD (argo.theedgestory.org)"
echo "  - Grafana (grafana.theedgestory.org)"
echo "  - Kafka UI (kafka.theedgestory.org)"
echo ""
echo "⚠️  WARNING: Services will be PUBLICLY accessible (no auth)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted"
  exit 1
fi

echo ""
echo "1️⃣ Removing OAuth2 auth from ArgoCD..."
kubectl annotate ingress argocd-server -n argocd \
  nginx.ingress.kubernetes.io/auth-url- \
  nginx.ingress.kubernetes.io/auth-signin- \
  --overwrite && echo "   ✅ ArgoCD auth removed"

echo ""
echo "2️⃣ Removing OAuth2 auth from Grafana..."
kubectl annotate ingress grafana -n monitoring \
  nginx.ingress.kubernetes.io/auth-url- \
  nginx.ingress.kubernetes.io/auth-signin- \
  --overwrite 2>/dev/null && echo "   ✅ Grafana auth removed" || echo "   ⚠️  Grafana ingress not found"

echo ""
echo "3️⃣ Removing OAuth2 auth from Kafka UI..."
kubectl annotate ingress kafka-ui -n infrastructure \
  nginx.ingress.kubernetes.io/auth-url- \
  nginx.ingress.kubernetes.io/auth-signin- \
  --overwrite 2>/dev/null && echo "   ✅ Kafka UI auth removed" || echo "   ⚠️  Kafka UI ingress not found"

echo ""
echo "4️⃣ Waiting 10 seconds for changes to propagate..."
sleep 10

echo ""
echo "5️⃣ Testing access..."
echo ""
echo "   ArgoCD:"
curl -I https://argo.theedgestory.org/ 2>&1 | grep "HTTP" | head -1

echo "   Grafana:"
curl -I https://grafana.theedgestory.org/ 2>&1 | grep "HTTP" | head -1

echo ""
echo "✅ DONE!"
echo ""
echo "🌐 You can now access (NO AUTHENTICATION):"
echo "   - https://argo.theedgestory.org"
echo "   - https://grafana.theedgestory.org"
echo "   - https://kafka.theedgestory.org"
echo ""
echo "⚠️  IMPORTANT: Re-enable OAuth2 after fixing certificate:"
echo ""
echo "   1. Fix certificate issue:"
echo "      bash quick-cert-fix.sh"
echo ""
echo "   2. Verify certificate exists:"
echo "      kubectl get secret oauth2-proxy-tls -n oauth2-proxy"
echo ""
echo "   3. Re-enable OAuth2 on all services:"
echo "      bash enable-oauth2-all-services.sh"
