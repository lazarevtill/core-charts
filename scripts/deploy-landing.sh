#!/bin/bash
# Deploy The Edge Story landing page to theedgestory.org
# Note: Works with Cloudflare Tunnel - TLS terminated at Cloudflare

set -e

cd "$(dirname "$0")/../landing"

echo "🌌 Deploying The Edge Story landing page..."
echo ""

# Generate ConfigMap from HTML files
echo "📦 Creating ConfigMap from HTML files..."
kubectl create configmap landing-page \
  --from-file=index.html=index.html \
  --from-file=privacy-policy.html=privacy-policy.html \
  --from-file=terms-of-service.html=terms-of-service.html \
  --namespace=default \
  --dry-run=client -o yaml > landing-configmap.yaml

echo "✅ ConfigMap created"
echo ""

# Apply ConfigMap
echo "📤 Applying ConfigMap..."
kubectl apply -f landing-configmap.yaml

# Apply deployment and ingress
echo "🚀 Applying deployment and ingress..."
kubectl apply -f deploy-landing.yaml

# Wait for rollout
echo "⏳ Waiting for deployment..."
kubectl rollout status deployment/landing-page --timeout=120s

echo ""
echo "✅ Landing page deployed!"
echo ""
echo "URLs:"
echo "  🌐 https://theedgestory.org"
echo "  🔒 https://theedgestory.org/privacy-policy.html"
echo "  📜 https://theedgestory.org/terms-of-service.html"
echo ""
echo "💡 Note: Using Cloudflare Tunnel for TLS termination"
echo ""
