#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔧 OAuth2 Force Fix - Certificate & ArgoCD 500 Error"
echo "====================================================="
echo "Using KUBECONFIG: $KUBECONFIG"
echo ""

echo ""
echo "1️⃣ Checking current OAuth2 TLS secret status..."
if kubectl get secret oauth2-proxy-tls -n oauth2-proxy &>/dev/null; then
  echo "   ✅ TLS secret exists"
  kubectl get secret oauth2-proxy-tls -n oauth2-proxy -o jsonpath='{.metadata.creationTimestamp}' | xargs -I {} echo "   Created: {}"
else
  echo "   ❌ TLS secret missing - this is the problem!"
fi

echo ""
echo "2️⃣ Checking Certificate resource..."
if kubectl get certificate -n oauth2-proxy &>/dev/null; then
  echo "   ✅ Certificate resource exists"
  kubectl get certificate -n oauth2-proxy
  echo ""
  echo "   Certificate details:"
  kubectl describe certificate -n oauth2-proxy
else
  echo "   ❌ Certificate resource missing"
  echo ""
  echo "   📝 Creating Certificate resource manually..."

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: oauth2-proxy-tls
  namespace: oauth2-proxy
spec:
  secretName: oauth2-proxy-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - auth.theedgestory.org
EOF

  echo "   ✅ Certificate resource created"
fi

echo ""
echo "3️⃣ Waiting for certificate to be issued (60 seconds)..."
sleep 10
echo "   10 seconds..."
sleep 10
echo "   20 seconds..."
sleep 10
echo "   30 seconds..."
sleep 10
echo "   40 seconds..."
sleep 10
echo "   50 seconds..."
sleep 10
echo "   60 seconds - checking status..."

echo ""
echo "4️⃣ Checking certificate status..."
kubectl get certificate -n oauth2-proxy -o wide
echo ""
kubectl describe certificate oauth2-proxy-tls -n oauth2-proxy | tail -20

echo ""
echo "5️⃣ Checking if TLS secret was created..."
if kubectl get secret oauth2-proxy-tls -n oauth2-proxy &>/dev/null; then
  echo "   ✅ TLS secret created successfully!"
  kubectl get secret oauth2-proxy-tls -n oauth2-proxy
else
  echo "   ❌ TLS secret still missing"
  echo ""
  echo "   Checking CertificateRequest status..."
  kubectl get certificaterequest -n oauth2-proxy
  echo ""
  echo "   Recent cert-manager logs:"
  kubectl logs -n cert-manager -l app=cert-manager --tail=20
  echo ""
  echo "   ⚠️  Certificate issuance may take up to 5 minutes."
  echo "   Check status with: kubectl get certificate -n oauth2-proxy -w"
  exit 1
fi

echo ""
echo "6️⃣ Restarting nginx-ingress to pick up new certificate..."
kubectl rollout restart deployment -n kube-system -l app.kubernetes.io/name=ingress-nginx 2>/dev/null || \
kubectl delete pod -n kube-system -l app.kubernetes.io/name=ingress-nginx

echo "   ✅ nginx-ingress restarted"

echo ""
echo "7️⃣ Waiting for nginx-ingress to be ready..."
sleep 10
kubectl wait --for=condition=ready pod -n kube-system -l app.kubernetes.io/name=ingress-nginx --timeout=60s

echo ""
echo "8️⃣ Testing OAuth2 auth endpoint..."
sleep 5
curl -I https://auth.theedgestory.org/oauth2/auth 2>&1 | grep -E "(HTTP|Location|X-Auth)" | head -10

echo ""
echo "9️⃣ Testing ArgoCD login page..."
curl -I https://argo.theedgestory.org/login 2>&1 | grep -E "(HTTP|Location)" | head -5

echo ""
echo "✅ DONE!"
echo ""
echo "🔍 If ArgoCD still shows 500 error, check:"
echo "   - ArgoCD server logs: kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50"
echo "   - OAuth2 Proxy logs: kubectl logs -n oauth2-proxy -l app=oauth2-proxy --tail=50"
echo "   - nginx-ingress logs: kubectl logs -n kube-system -l app.kubernetes.io/name=ingress-nginx --tail=50"
echo ""
echo "🌐 Try accessing: https://argo.theedgestory.org"
echo "   (Should redirect to Google login)"
