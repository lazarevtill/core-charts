#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔐 OAuth2 Certificate Fix & Diagnosis"
echo "======================================"
echo "Using KUBECONFIG: $KUBECONFIG"
echo ""

echo ""
echo "1️⃣ Checking cert-manager status..."
kubectl get pods -n cert-manager

echo ""
echo "2️⃣ Checking for Certificate resource..."
kubectl get certificate -n oauth2-proxy 2>/dev/null || echo "   ❌ No Certificate resource found"

echo ""
echo "3️⃣ Checking for CertificateRequest..."
kubectl get certificaterequest -n oauth2-proxy 2>/dev/null || echo "   ❌ No CertificateRequest found"

echo ""
echo "4️⃣ Checking OAuth2 Proxy ingress..."
kubectl get ingress oauth2-proxy -n oauth2-proxy -o yaml | grep -A 20 "annotations:\|tls:"

echo ""
echo "5️⃣ Checking if TLS secret exists..."
kubectl get secret oauth2-proxy-tls -n oauth2-proxy 2>/dev/null && echo "   ✅ TLS secret exists" || echo "   ❌ TLS secret missing"

echo ""
echo "6️⃣ Checking cert-manager logs for errors..."
kubectl logs -n cert-manager -l app=cert-manager --tail=30 | grep -i "oauth2\|error" || echo "   No recent errors found"

echo ""
echo "7️⃣ Checking Let's Encrypt ClusterIssuer..."
kubectl get clusterissuer letsencrypt-prod -o yaml 2>/dev/null | grep -A 10 "status:" || echo "   ❌ ClusterIssuer not found"

echo ""
echo "8️⃣ Testing OAuth2 auth endpoint (internal)..."
kubectl run test-oauth2 --image=curlimages/curl --rm -i --restart=Never -- \
  curl -I http://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180/oauth2/auth 2>&1 | head -5 || echo "   Test failed"

echo ""
echo "9️⃣ Testing OAuth2 auth endpoint (external)..."
curl -I https://auth.theedgestory.org/oauth2/auth 2>&1 | grep -E "(HTTP|Location|X-Auth)" | head -10

echo ""
echo "🔟 Checking nginx-ingress logs for OAuth2 errors..."
kubectl logs -n kube-system -l app.kubernetes.io/name=ingress-nginx --tail=50 | grep -i "oauth2\|auth.theedgestory" || echo "   No recent errors"

echo ""
echo "======================================"
echo "🔧 POTENTIAL FIX:"
echo ""
echo "If Certificate resource is missing, cert-manager should create it automatically from the ingress annotation."
echo "If it's stuck, try:"
echo ""
echo "  # Force cert-manager to reconcile the ingress"
echo "  kubectl annotate ingress oauth2-proxy -n oauth2-proxy cert-manager.io/issue-temporary-certificate=true --overwrite"
echo ""
echo "  # Or delete and recreate the ingress to trigger certificate creation"
echo "  kubectl delete ingress oauth2-proxy -n oauth2-proxy"
echo "  kubectl apply -f oauth2-proxy/deployment.yaml"
echo ""
echo "  # Check certificate status after 30 seconds"
echo "  sleep 30"
echo "  kubectl get certificate -n oauth2-proxy"
echo "  kubectl describe certificate oauth2-proxy-tls -n oauth2-proxy"
