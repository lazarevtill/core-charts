#!/bin/bash
set -e

echo "🔐 Setting up OAuth2 Proxy with Google Authentication"
echo "======================================================"

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
echo "5️⃣ Adding auth annotations to ingresses..."

# ArgoCD
kubectl annotate ingress argocd-server -n argocd \
  nginx.ingress.kubernetes.io/auth-url="https://auth.theedgestory.org/oauth2/auth" \
  nginx.ingress.kubernetes.io/auth-signin="https://auth.theedgestory.org/oauth2/start?rd=\$scheme://\$host\$request_uri" \
  --overwrite || echo "   ArgoCD ingress not found (OK)"

# Grafana (if exists)
kubectl annotate ingress grafana -n monitoring \
  nginx.ingress.kubernetes.io/auth-url="https://auth.theedgestory.org/oauth2/auth" \
  nginx.ingress.kubernetes.io/auth-signin="https://auth.theedgestory.org/oauth2/start?rd=\$scheme://\$host\$request_uri" \
  --overwrite 2>/dev/null || echo "   Grafana ingress not found (OK)"

echo ""
echo "✅ DONE!"
echo ""
echo "📊 OAuth2 Proxy deployed:"
echo "   - Auth URL: https://auth.theedgestory.org"
echo "   - Allowed user: dcversus@gmail.com"
echo ""
echo "🔒 Protected services:"
echo "   - ArgoCD: https://argo.theedgestory.org"
echo "   - Grafana: https://grafana.theedgestory.org (if deployed)"
echo ""
echo "🌐 Google OAuth Redirect URI (add to Google Console):"
echo "   https://auth.theedgestory.org/oauth2/callback"
