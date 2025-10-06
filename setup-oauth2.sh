#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔐 Setting up OAuth2 Proxy with Google Authentication"
echo "======================================================"
echo "Using KUBECONFIG: $KUBECONFIG"
echo ""

# Check required environment variables
if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
  echo "❌ Error: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set"
  echo ""
  echo "Usage:"
  echo "  export GOOGLE_CLIENT_ID='your-client-id'"
  echo "  export GOOGLE_CLIENT_SECRET='your-client-secret'"
  echo "  bash setup-oauth2.sh"
  exit 1
fi

# Generate cookie secret
echo ""
echo "1️⃣ Generating cookie secret..."
COOKIE_SECRET=$(openssl rand -base64 32 | head -c 32)
echo "   Cookie secret: ${COOKIE_SECRET:0:8}..."

# Update secret in deployment
echo ""
echo "2️⃣ Creating OAuth2 Proxy secret..."
kubectl create namespace oauth2-proxy --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic oauth2-proxy \
  --from-literal=client-id="$GOOGLE_CLIENT_ID" \
  --from-literal=client-secret="$GOOGLE_CLIENT_SECRET" \
  --from-literal=cookie-secret="$COOKIE_SECRET" \
  -n oauth2-proxy \
  --dry-run=client -o yaml | kubectl apply -f -

echo "   ✅ Secret created"

# Apply OAuth2 Proxy deployment
echo ""
echo "3️⃣ Deploying OAuth2 Proxy..."
kubectl apply -f oauth2-proxy/deployment.yaml

echo ""
echo "4️⃣ Waiting for OAuth2 Proxy to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/oauth2-proxy -n oauth2-proxy || true

echo ""
echo "5️⃣ Making sure OAuth2 Proxy ingress has NO auth (prevent infinite redirect)..."
kubectl annotate ingress oauth2-proxy -n oauth2-proxy \
  nginx.ingress.kubernetes.io/auth-url- \
  nginx.ingress.kubernetes.io/auth-signin- \
  --overwrite 2>/dev/null || true

echo ""
echo "6️⃣ Adding auth annotations to ALL service ingresses..."

# Auth annotation values
AUTH_URL="https://auth.theedgestory.org/oauth2/auth"
AUTH_SIGNIN="https://auth.theedgestory.org/oauth2/start?rd=\$scheme://\$host\$request_uri"

# ArgoCD
kubectl annotate ingress argocd-server -n argocd \
  nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
  nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
  --overwrite && echo "   ✅ ArgoCD protected" || echo "   ⚠️  ArgoCD ingress not found"

# Grafana
kubectl annotate ingress grafana -n monitoring \
  nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
  nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
  --overwrite 2>/dev/null && echo "   ✅ Grafana protected" || echo "   ⚠️  Grafana ingress not found"

# MinIO/S3 Admin
kubectl annotate ingress minio -n infrastructure \
  nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
  nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
  --overwrite 2>/dev/null && echo "   ✅ MinIO protected" || \
kubectl annotate ingress minio-console -n infrastructure \
  nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
  nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
  --overwrite 2>/dev/null && echo "   ✅ MinIO Console protected" || echo "   ⚠️  MinIO ingress not found"

# Kafka UI
kubectl annotate ingress kafka-ui -n infrastructure \
  nginx.ingress.kubernetes.io/auth-url="$AUTH_URL" \
  nginx.ingress.kubernetes.io/auth-signin="$AUTH_SIGNIN" \
  --overwrite 2>/dev/null && echo "   ✅ Kafka UI protected" || echo "   ⚠️  Kafka UI ingress not found"

echo ""
echo "✅ DONE!"
echo ""
echo "📊 OAuth2 Proxy deployed:"
echo "   - Auth URL: https://auth.theedgestory.org"
echo "   - Allowed user: dcversus@gmail.com"
echo ""
echo "🔒 Protected services (Google OAuth required):"
echo "   - ArgoCD: https://argo.theedgestory.org"
echo "   - Grafana: https://grafana.theedgestory.org"
echo "   - MinIO/S3: https://s3-admin.theedgestory.org"
echo "   - Kafka UI: https://kafka.theedgestory.org"
echo ""
echo "🌐 Google OAuth Redirect URI (add to Google Console):"
echo "   https://auth.theedgestory.org/oauth2/callback"
