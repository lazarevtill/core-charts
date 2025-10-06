#!/bin/bash
# Install nginx-ingress controller as alternative to Traefik

set -e

echo "📦 Installing nginx-ingress controller..."
echo ""

# Add nginx-ingress helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install nginx-ingress with a different service type to avoid conflicts with Traefik
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.loadBalancerIP=46.62.223.198 \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClass=nginx \
  --wait

echo ""
echo "✅ nginx-ingress controller installed"
echo ""
echo "Now update the landing page ingress to use nginx class:"
echo "  kubectl patch ingress landing-page -n default -p '{\"spec\":{\"ingressClassName\":\"nginx\"}}'"
