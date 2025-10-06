#!/bin/bash
# Script to create ConfigMap from landing page files

set -e

echo "🌐 Creating ConfigMap for The Edge Story landing page..."

kubectl create configmap landing-page \
  --from-file=index.html=index.html \
  --from-file=privacy-policy.html=privacy-policy.html \
  --from-file=terms-of-service.html=terms-of-service.html \
  --namespace=default \
  --dry-run=client -o yaml > landing-configmap.yaml

echo "✅ ConfigMap created: landing-configmap.yaml"
echo ""
echo "To deploy:"
echo "  kubectl apply -f landing-configmap.yaml"
echo "  kubectl apply -f deploy-landing.yaml"
