#!/bin/bash
# Migrate from Traefik to nginx-ingress controller
# Educational project - simple and reliable setup

set -e

echo "🔄 Migrating from Traefik to nginx-ingress..."
echo ""

# Step 1: Install nginx-ingress
echo "📦 Installing nginx-ingress controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.ingressClassResource.default=true \
  --wait

echo "✅ nginx-ingress installed"
echo ""

# Step 2: Update all ingresses to use nginx class
echo "🔧 Updating ingresses to use nginx..."

# Get all ingresses and update them
kubectl get ingress -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read ns name; do
  echo "  Updating ingress: $ns/$name"
  kubectl patch ingress $name -n $ns --type='json' -p='[{"op": "replace", "path": "/spec/ingressClassName", "value":"nginx"}]' 2>/dev/null || true
done

echo "✅ All ingresses updated"
echo ""

# Step 3: Remove Traefik (optional - can keep for now)
echo "⚠️  Traefik is still running. To remove it:"
echo "   helm uninstall traefik -n kube-system"
echo ""

# Step 4: Get the LoadBalancer IP
echo "🌐 Getting LoadBalancer IP..."
kubectl get svc -n ingress-nginx ingress-nginx-controller

echo ""
echo "✅ Migration complete!"
echo ""
echo "Test your landing page:"
echo "  curl -I https://theedgestory.org"
