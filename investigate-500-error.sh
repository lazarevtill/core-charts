#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔍 500 Internal Server Error Investigation"
echo "=========================================="
echo ""

echo "1️⃣ Testing ArgoCD endpoint from outside:"
echo ""
curl -v https://argo.theedgestory.org/ 2>&1 | grep -E "(HTTP|Server|Location|X-|erro)" | head -20
echo ""

echo "2️⃣ ArgoCD ingress configuration:"
echo ""
kubectl get ingress argocd-server -n argocd -o yaml | grep -A 30 "annotations:\|spec:"
echo ""

echo "3️⃣ nginx-ingress controller logs (last 50 lines, filtering for argo):"
echo ""
kubectl logs -n kube-system -l app.kubernetes.io/name=ingress-nginx --tail=100 | grep -i "argo\|500\|error" | tail -30
echo ""

echo "4️⃣ Testing OAuth2 auth endpoint (internal from cluster):"
echo ""
kubectl run test-oauth2-internal --image=curlimages/curl --rm -i --restart=Never --command -- \
  curl -v http://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180/oauth2/auth 2>&1 | grep -E "(HTTP|erro|Conn)" || echo "Test failed"
echo ""

echo "5️⃣ Testing OAuth2 auth endpoint (external HTTPS):"
echo ""
curl -v https://auth.theedgestory.org/oauth2/auth 2>&1 | grep -E "(HTTP|erro|SSL|certificate|Conn)" | head -20
echo ""

echo "6️⃣ OAuth2 Proxy pod logs (last 50 lines):"
echo ""
kubectl logs -n oauth2-proxy -l app=oauth2-proxy --tail=50 | tail -30
echo ""

echo "7️⃣ ArgoCD server pod logs (last 30 lines, errors only):"
echo ""
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50 | grep -i "error\|warn\|fail" | tail -20 || echo "No errors in ArgoCD logs"
echo ""

echo "8️⃣ ArgoCD server pod status:"
echo ""
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
echo ""

echo "9️⃣ OAuth2 Proxy TLS certificate status:"
echo ""
kubectl get certificate oauth2-proxy-tls -n oauth2-proxy -o wide 2>/dev/null || echo "Certificate not found"
kubectl get secret oauth2-proxy-tls -n oauth2-proxy 2>/dev/null && echo "   ✅ TLS secret exists" || echo "   ❌ TLS secret MISSING - THIS IS THE PROBLEM"
echo ""

echo "🔟 CertificateRequest status and errors:"
echo ""
kubectl describe certificaterequest -n oauth2-proxy 2>/dev/null | tail -30 || echo "No CertificateRequest found"
echo ""

echo "1️⃣1️⃣ cert-manager logs (looking for oauth2 errors):"
echo ""
kubectl logs -n cert-manager -l app=cert-manager --tail=100 | grep -i "oauth2\|auth.theedgestory\|error" | tail -20 || echo "No relevant cert-manager logs"
echo ""

echo "1️⃣2️⃣ DNS resolution check:"
echo ""
echo "   auth.theedgestory.org:"
dig +short auth.theedgestory.org || nslookup auth.theedgestory.org | grep Address | tail -1
echo ""
echo "   argo.theedgestory.org:"
dig +short argo.theedgestory.org || nslookup argo.theedgestory.org | grep Address | tail -1
echo ""

echo "1️⃣3️⃣ nginx-ingress SSL/TLS errors:"
echo ""
kubectl logs -n kube-system -l app.kubernetes.io/name=ingress-nginx --tail=200 | grep -i "ssl\|tls\|certificate\|oauth2\|auth.theedgestory" | tail -30
echo ""

echo "=========================================="
echo "📋 SUMMARY:"
echo ""

# Check if TLS secret exists
if kubectl get secret oauth2-proxy-tls -n oauth2-proxy &>/dev/null; then
  echo "✅ OAuth2 TLS certificate exists"
  echo ""
  echo "If 500 error persists, check:"
  echo "  - nginx-ingress logs above for actual error"
  echo "  - OAuth2 Proxy configuration"
  echo "  - ArgoCD can reach oauth2-proxy service"
else
  echo "❌ ROOT CAUSE: OAuth2 TLS certificate MISSING"
  echo ""
  echo "This is why you get 500 errors:"
  echo "  1. ArgoCD ingress has auth annotation pointing to https://auth.theedgestory.org/oauth2/auth"
  echo "  2. nginx-ingress tries to validate auth by calling that URL"
  echo "  3. TLS certificate for auth.theedgestory.org doesn't exist"
  echo "  4. HTTPS request fails"
  echo "  5. nginx returns 500 Internal Server Error"
  echo ""
  echo "SOLUTION:"
  echo "  Option 1 (immediate access): bash emergency-disable-oauth-all.sh"
  echo "  Option 2 (fix certificate): bash quick-cert-fix.sh"
fi
