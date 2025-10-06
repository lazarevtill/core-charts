#!/bin/bash
# Clean install of nginx-ingress (remove old non-Helm installation)

set -e

echo "🧹 Cleaning old nginx-ingress installation..."

# Delete all nginx-ingress resources
kubectl delete all --all -n ingress-nginx 2>/dev/null || true
kubectl delete serviceaccount --all -n ingress-nginx 2>/dev/null || true
kubectl delete configmap --all -n ingress-nginx 2>/dev/null || true
kubectl delete secret --all -n ingress-nginx 2>/dev/null || true
kubectl delete clusterrole ingress-nginx 2>/dev/null || true
kubectl delete clusterrolebinding ingress-nginx 2>/dev/null || true
kubectl delete validatingwebhookconfigurations ingress-nginx-admission 2>/dev/null || true
kubectl delete namespace ingress-nginx 2>/dev/null || true

echo "Waiting for cleanup..."
sleep 10

echo ""
echo "📦 Installing nginx-ingress via Helm..."

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.ingressClassResource.default=true \
  --wait --timeout=5m

echo ""
echo "✅ nginx-ingress installed successfully!"
echo ""

# Update landing page ingress
echo "🔧 Updating landing page ingress..."
kubectl patch ingress landing-page -n default --type='json' -p='[{"op": "replace", "path": "/spec/ingressClassName", "value":"nginx"}]' 2>/dev/null || \
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: landing-page
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: theedgestory.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: landing-page
            port:
              number: 80
EOF

echo ""
echo "🌐 Getting LoadBalancer IP..."
kubectl get svc -n ingress-nginx

echo ""
echo "✅ Done! Test with: curl -I http://theedgestory.org"
