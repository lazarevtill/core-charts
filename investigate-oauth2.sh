#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
export KUBECONFIG=~/.kube/config

echo "🔍 OAuth2 Proxy Investigation"
echo "=============================="
echo "Using KUBECONFIG: $KUBECONFIG"
echo ""

echo ""
echo "1️⃣ OAuth2 Proxy Pods:"
kubectl get pods -n oauth2-proxy -o wide

echo ""
echo "2️⃣ OAuth2 Proxy Deployment Status:"
kubectl get deployment oauth2-proxy -n oauth2-proxy

echo ""
echo "3️⃣ OAuth2 Proxy Service:"
kubectl get svc oauth2-proxy -n oauth2-proxy

echo ""
echo "4️⃣ OAuth2 Proxy Ingress:"
kubectl get ingress oauth2-proxy -n oauth2-proxy -o yaml | grep -A 10 "metadata:" | head -20

echo ""
echo "5️⃣ OAuth2 Proxy Ingress Annotations:"
kubectl get ingress oauth2-proxy -n oauth2-proxy -o jsonpath='{.metadata.annotations}' | python3 -m json.tool 2>/dev/null || echo "No annotations or invalid JSON"

echo ""
echo "6️⃣ OAuth2 Proxy Secret:"
kubectl get secret oauth2-proxy -n oauth2-proxy -o jsonpath='{.data}' | python3 -c "import sys, json; data=json.load(sys.stdin); print('Keys:', list(data.keys()))"

echo ""
echo "7️⃣ OAuth2 Proxy ConfigMap (Email Whitelist):"
kubectl get configmap oauth2-proxy-emails -n oauth2-proxy -o jsonpath='{.data.authenticated-emails-list\.txt}'

echo ""
echo "8️⃣ Recent OAuth2 Proxy Logs:"
kubectl logs -n oauth2-proxy deployment/oauth2-proxy --tail=30 --all-containers=true

echo ""
echo "9️⃣ ArgoCD Ingress Auth Annotations:"
kubectl get ingress argocd-server -n argocd -o jsonpath='{.metadata.annotations}' | python3 -c "import sys, json; data=json.load(sys.stdin); auth_keys=[k for k in data.keys() if 'auth' in k.lower()]; print('Auth annotations:'); [print(f'  {k}: {data[k][:80]}...') for k in auth_keys]" 2>/dev/null || echo "No auth annotations"

echo ""
echo "🔟 Grafana Ingress Auth Annotations:"
kubectl get ingress grafana -n monitoring -o jsonpath='{.metadata.annotations}' | python3 -c "import sys, json; data=json.load(sys.stdin); auth_keys=[k for k in data.keys() if 'auth' in k.lower()]; print('Auth annotations:'); [print(f'  {k}: {data[k][:80]}...') for k in auth_keys]" 2>/dev/null || echo "Grafana ingress not found or no auth annotations"

echo ""
echo "1️⃣1️⃣ Test OAuth2 Auth Endpoint:"
echo "Testing: https://auth.theedgestory.org/oauth2/auth"
curl -I https://auth.theedgestory.org/oauth2/auth 2>&1 | grep -E "(HTTP|Location|Set-Cookie)" | head -5

echo ""
echo "1️⃣2️⃣ Test OAuth2 Start Endpoint:"
echo "Testing: https://auth.theedgestory.org/oauth2/start?rd=https://argo.theedgestory.org"
curl -I "https://auth.theedgestory.org/oauth2/start?rd=https://argo.theedgestory.org" 2>&1 | grep -E "(HTTP|Location)" | head -5

echo ""
echo "1️⃣3️⃣ Test ArgoCD Direct Access:"
echo "Testing: https://argo.theedgestory.org"
curl -I https://argo.theedgestory.org 2>&1 | grep -E "(HTTP|Location)" | head -5

echo ""
echo "=============================="
echo "✅ Investigation Complete"
