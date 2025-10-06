#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔐 Enable Google OAuth2 on ALL Services"
echo "========================================"
echo "Using KUBECONFIG: $KUBECONFIG"
echo ""
echo "This will add OAuth2 authentication to:"
echo "  - ArgoCD (argo.theedgestory.org)"
echo "  - Grafana (grafana.theedgestory.org)"
echo "  - MinIO/S3 Admin (s3-admin.theedgestory.org)"
echo "  - Kafka UI (kafka.theedgestory.org)"
echo ""
echo "Only dcversus@gmail.com will be allowed to access"
echo ""

# Auth annotation values
AUTH_URL="https://auth.theedgestory.org/oauth2/auth"
AUTH_SIGNIN="https://auth.theedgestory.org/oauth2/start?rd=\$scheme://\$host\$request_uri"

echo ""
echo "1️⃣ Checking OAuth2 Proxy status..."
if ! kubectl get deployment oauth2-proxy -n oauth2-proxy &>/dev/null; then
  echo "   ❌ OAuth2 Proxy not deployed!"
  echo ""
  echo "   Run first: bash setup-oauth2.sh"
  exit 1
fi

OAUTH2_READY=$(kubectl get deployment oauth2-proxy -n oauth2-proxy -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
echo "   OAuth2 Proxy replicas ready: $OAUTH2_READY/2"

if [ "$OAUTH2_READY" != "2" ]; then
  echo "   ⚠️  OAuth2 Proxy not fully ready, continuing anyway..."
fi

echo ""
echo "2️⃣ Checking TLS certificate status..."
if kubectl get secret oauth2-proxy-tls -n oauth2-proxy &>/dev/null; then
  echo "   ✅ TLS certificate exists"
else
  echo "   ⚠️  TLS certificate missing - OAuth2 may not work until certificate is issued"
  echo "   Certificate status:"
  kubectl get certificate oauth2-proxy-tls -n oauth2-proxy 2>/dev/null || echo "   Certificate resource not found"
fi

echo ""
echo "3️⃣ Making sure OAuth2 Proxy ingress has NO auth (prevent infinite redirect)..."
kubectl annotate ingress oauth2-proxy -n oauth2-proxy \
  nginx.ingress.kubernetes.io/auth-url- \
  nginx.ingress.kubernetes.io/auth-signin- \
  --overwrite 2>/dev/null || echo "   OAuth2 Proxy ingress not found"

echo ""
echo "4️⃣ Adding auth to ArgoCD..."
if kubectl get ingress argocd-server -n argocd &>/dev/null; then
  kubectl annotate ingress argocd-server -n argocd \
    nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
    nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
    --overwrite
  echo "   ✅ ArgoCD: https://argo.theedgestory.org"
else
  echo "   ⚠️  ArgoCD ingress not found"
fi

echo ""
echo "5️⃣ Adding auth to Grafana..."
if kubectl get ingress grafana -n monitoring &>/dev/null; then
  kubectl annotate ingress grafana -n monitoring \
    nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
    nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
    --overwrite
  echo "   ✅ Grafana: https://grafana.theedgestory.org"
else
  echo "   ⚠️  Grafana ingress not found (may not be deployed yet)"
fi

echo ""
echo "6️⃣ Adding auth to MinIO/S3 Admin..."
if kubectl get ingress minio -n infrastructure &>/dev/null; then
  kubectl annotate ingress minio -n infrastructure \
    nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
    nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
    --overwrite
  echo "   ✅ MinIO: https://s3-admin.theedgestory.org"
elif kubectl get ingress minio-console -n infrastructure &>/dev/null; then
  kubectl annotate ingress minio-console -n infrastructure \
    nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
    nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
    --overwrite
  echo "   ✅ MinIO Console: https://s3-admin.theedgestory.org"
else
  echo "   ⚠️  MinIO ingress not found (may not be deployed yet)"
fi

echo ""
echo "7️⃣ Adding auth to Kafka UI..."
if kubectl get ingress kafka-ui -n infrastructure &>/dev/null; then
  kubectl annotate ingress kafka-ui -n infrastructure \
    nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
    nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
    --overwrite
  echo "   ✅ Kafka UI: https://kafka.theedgestory.org"
else
  echo "   ⚠️  Kafka UI ingress not found (may not be deployed yet)"
fi

echo ""
echo "8️⃣ Listing all protected ingresses..."
echo ""
kubectl get ingress -A -o json | jq -r '
  .items[] |
  select(.metadata.annotations["nginx.ingress.kubernetes.io/auth-url"] != null) |
  "   ✅ \(.metadata.namespace)/\(.metadata.name) -> \(.spec.rules[0].host)"
' 2>/dev/null || echo "   (jq not available, skipping)"

echo ""
echo "✅ DONE!"
echo ""
echo "🔐 All services now require Google OAuth2 authentication"
echo "   Only dcversus@gmail.com can access"
echo ""
echo "🌐 Protected services:"
echo "   - https://argo.theedgestory.org (ArgoCD)"
echo "   - https://grafana.theedgestory.org (Grafana)"
echo "   - https://s3-admin.theedgestory.org (MinIO)"
echo "   - https://kafka.theedgestory.org (Kafka UI)"
echo ""
echo "⚠️  If you get 500 errors, check OAuth2 TLS certificate:"
echo "   kubectl get certificate oauth2-proxy-tls -n oauth2-proxy"
echo "   kubectl get secret oauth2-proxy-tls -n oauth2-proxy"
echo ""
echo "🔧 To fix certificate issues:"
echo "   bash fix-cert-dns-check.sh"
