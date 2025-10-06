#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔧 Fix Let's Encrypt ClusterIssuer"
echo "==================================="
echo ""

echo "1️⃣ Checking if letsencrypt-prod ClusterIssuer exists..."
if kubectl get clusterissuer letsencrypt-prod &>/dev/null; then
  echo "   ✅ ClusterIssuer exists"
  kubectl get clusterissuer letsencrypt-prod -o yaml | grep -A 10 "spec:\|status:"
else
  echo "   ❌ ClusterIssuer NOT FOUND - creating it now..."
  echo ""
  kubectl apply -f cert-manager/letsencrypt-issuer.yaml
  echo "   ✅ ClusterIssuer created"
fi

echo ""
echo "2️⃣ Checking cert-manager pods..."
kubectl get pods -n cert-manager

echo ""
echo "3️⃣ Waiting 10 seconds for cert-manager to recognize ClusterIssuer..."
sleep 10

echo ""
echo "4️⃣ Verifying ClusterIssuer is ready..."
kubectl get clusterissuer letsencrypt-prod -o wide

echo ""
echo "5️⃣ Deleting old failed certificate requests..."
kubectl delete certificaterequest --all -n oauth2-proxy 2>/dev/null || echo "   No old requests found"
kubectl delete certificate oauth2-proxy-tls -n oauth2-proxy 2>/dev/null || echo "   No old certificate found"

echo ""
echo "6️⃣ Recreating OAuth2 Proxy ingress to trigger new certificate..."
kubectl delete ingress oauth2-proxy -n oauth2-proxy 2>/dev/null || true
sleep 2
kubectl apply -f oauth2-proxy/deployment.yaml

echo "   ✅ Ingress recreated"

echo ""
echo "7️⃣ Waiting 15 seconds for cert-manager to process..."
sleep 15

echo ""
echo "8️⃣ Checking new certificate status..."
kubectl get certificate -n oauth2-proxy
kubectl get certificaterequest -n oauth2-proxy

echo ""
echo "9️⃣ Checking for ACME challenges..."
kubectl get challenges -n oauth2-proxy 2>/dev/null || echo "   No challenges yet (may appear in a few seconds)"

echo ""
echo "🔟 Waiting 30 more seconds for Let's Encrypt to issue certificate..."
sleep 30

echo ""
echo "1️⃣1️⃣ Final check:"
if kubectl get secret oauth2-proxy-tls -n oauth2-proxy &>/dev/null; then
  echo "   ✅ SUCCESS! TLS certificate issued!"
  kubectl get secret oauth2-proxy-tls -n oauth2-proxy
  echo ""
  echo "   Testing OAuth2 endpoint:"
  curl -I https://auth.theedgestory.org/oauth2/auth 2>&1 | grep HTTP | head -1
  echo ""
  echo "   ✅ OAuth2 should now work!"
  echo "   Try accessing: https://argo.theedgestory.org"
else
  echo "   ⚠️  Certificate not issued yet"
  echo ""
  echo "   Certificate status:"
  kubectl describe certificate oauth2-proxy-tls -n oauth2-proxy | tail -20
  echo ""
  echo "   This may be due to DNS issue:"
  echo "   - auth.theedgestory.org currently resolves to: $(dig +short auth.theedgestory.org | head -1)"
  echo "   - Should resolve to: 46.62.223.198"
  echo ""
  echo "   Fix DNS in Cloudflare:"
  echo "   1. Go to Cloudflare DNS settings"
  echo "   2. Find 'auth.theedgestory.org' A record"
  echo "   3. Set IP to: 46.62.223.198"
  echo "   4. DISABLE proxy (orange cloud) - set to DNS only (gray cloud)"
  echo "   5. Wait 2 minutes for DNS propagation"
  echo "   6. Run this script again"
fi

echo ""
echo "==================================="
echo "✅ DONE!"
