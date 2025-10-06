#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔧 Quick Certificate Fix - Delete & Recreate"
echo "============================================"
echo ""

echo "1️⃣ Current certificate status:"
kubectl get certificate oauth2-proxy-tls -n oauth2-proxy
echo ""

echo "2️⃣ CertificateRequest details:"
kubectl describe certificaterequest -n oauth2-proxy 2>/dev/null | tail -20
echo ""

echo "3️⃣ Deleting stuck certificate and requests..."
kubectl delete certificate oauth2-proxy-tls -n oauth2-proxy
kubectl delete certificaterequest --all -n oauth2-proxy
kubectl delete challenges --all -n oauth2-proxy 2>/dev/null || true

echo "   ✅ Deleted"
echo ""

echo "4️⃣ Waiting 5 seconds for cleanup..."
sleep 5

echo ""
echo "5️⃣ Checking if ingress will auto-create certificate..."
kubectl get ingress oauth2-proxy -n oauth2-proxy -o jsonpath='{.metadata.annotations.cert-manager\.io/cluster-issuer}'
echo ""

echo ""
echo "6️⃣ Deleting and reapplying ingress to trigger cert-manager..."
kubectl delete ingress oauth2-proxy -n oauth2-proxy
sleep 2
kubectl apply -f oauth2-proxy/deployment.yaml

echo "   ✅ Ingress recreated"
echo ""

echo "7️⃣ Waiting 10 seconds for cert-manager to detect..."
sleep 10

echo ""
echo "8️⃣ New certificate status:"
kubectl get certificate -n oauth2-proxy 2>/dev/null || echo "   Not created yet"
kubectl get certificaterequest -n oauth2-proxy 2>/dev/null || echo "   No requests yet"

echo ""
echo "9️⃣ Waiting 30 more seconds for Let's Encrypt..."
sleep 30

echo ""
echo "🔟 Final check:"
kubectl get certificate oauth2-proxy-tls -n oauth2-proxy -o wide 2>/dev/null || echo "   Certificate not found"
kubectl get secret oauth2-proxy-tls -n oauth2-proxy 2>/dev/null && echo "   ✅ TLS SECRET EXISTS!" || echo "   ❌ TLS secret still missing"

echo ""
echo "============================================"
echo ""

if kubectl get secret oauth2-proxy-tls -n oauth2-proxy &>/dev/null; then
  echo "✅ SUCCESS! Certificate issued."
  echo ""
  echo "Testing OAuth2 endpoint:"
  curl -I https://auth.theedgestory.org/oauth2/auth 2>&1 | head -5
  echo ""
  echo "🌐 Try accessing: https://argo.theedgestory.org"
else
  echo "❌ Certificate still not issued. Checking logs..."
  echo ""
  echo "cert-manager logs:"
  kubectl logs -n cert-manager -l app=cert-manager --tail=30 | grep -i oauth2
  echo ""
  echo "Check DNS resolution:"
  dig +short auth.theedgestory.org
fi
