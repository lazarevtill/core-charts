#!/bin/bash
# Install nginx-ingress controller for The Edge Story
# Simple, reliable ingress solution for educational projects

set -e

echo "📦 Installing nginx-ingress controller..."
echo ""

# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

# Install nginx-ingress
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.ingressClassResource.default=true \
  --wait --timeout=5m

echo ""
echo "✅ nginx-ingress installed!"
echo ""

# Show LoadBalancer IP
echo "🌐 LoadBalancer IP:"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
echo ""
echo "✅ Done! Update your DNS to point to this IP"
