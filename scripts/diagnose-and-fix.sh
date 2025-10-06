#!/bin/bash
# Ultimate diagnosis and fix for landing page deployment

set -e

echo "🔍 DIAGNOSIS - Landing Page Issue"
echo "=================================="
echo ""

echo "1. Checking for Traefik remnants..."
kubectl get all -n kube-system | grep traefik || echo "✅ No Traefik resources in kube-system"
kubectl get svc -A | grep traefik || echo "✅ No Traefik services found"
echo ""

echo "2. Checking port conflicts on LoadBalancer..."
kubectl get svc -A | grep LoadBalancer
echo ""

echo "3. Checking nginx-ingress status..."
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
echo ""

echo "4. Checking landing-page ingress..."
kubectl get ingress landing-page -n default -o yaml
echo ""

echo "5. Checking what nginx-ingress sees..."
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=30 | grep -i "landing\|default" || echo "⚠️ nginx-ingress not seeing landing-page ingress"
echo ""

echo "=================================="
echo "🔧 APPLYING FIXES"
echo "=================================="
echo ""

echo "Fix 1: Ensure Traefik is completely removed..."
helm uninstall traefik -n kube-system 2>/dev/null || echo "Traefik already uninstalled"
kubectl delete svc traefik -n kube-system 2>/dev/null || true
kubectl delete deployment traefik -n kube-system 2>/dev/null || true
echo ""

echo "Fix 2: Recreate landing-page ingress with nginx class..."
kubectl delete ingress landing-page -n default 2>/dev/null || true
cat <<EOF | kubectl apply -f -
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

echo "Fix 3: Restart nginx-ingress to pick up changes..."
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
kubectl rollout status deployment -n ingress-nginx ingress-nginx-controller --timeout=60s
echo ""

echo "=================================="
echo "🧪 TESTING"
echo "=================================="
echo ""

echo "Waiting for nginx to reload..."
sleep 5

echo "Test 1: Check ingress has ADDRESS..."
kubectl get ingress landing-page -n default
echo ""

echo "Test 2: Check nginx-ingress logs..."
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=10
echo ""

echo "Test 3: Direct test to nginx-ingress controller..."
NGINX_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
echo "Testing from nginx pod: $NGINX_POD"
kubectl exec -n ingress-nginx $NGINX_POD -- curl -s -H "Host: theedgestory.org" http://localhost/ | head -20
echo ""

echo "=================================="
echo "✅ Diagnosis complete!"
echo ""
echo "Final test from outside:"
echo "  curl -I http://theedgestory.org"
