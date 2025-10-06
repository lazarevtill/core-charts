#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔍 OAuth2 Certificate DNS & HTTP-01 Challenge Check"
echo "===================================================="
echo ""

echo "1️⃣ Check DNS resolution for auth.theedgestory.org:"
echo "   Expected IP: 46.62.223.198"
echo ""
RESOLVED_IP=$(dig +short auth.theedgestory.org | tail -1)
echo "   Resolved IP: $RESOLVED_IP"
if [ "$RESOLVED_IP" = "46.62.223.198" ]; then
  echo "   ✅ DNS is correct"
else
  echo "   ❌ DNS mismatch! Should be 46.62.223.198"
fi

echo ""
echo "2️⃣ CertificateRequest status:"
kubectl get certificaterequest -n oauth2-proxy -o wide

echo ""
echo "3️⃣ Detailed CertificateRequest:"
kubectl describe certificaterequest -n oauth2-proxy | tail -40

echo ""
echo "4️⃣ Check for ACME challenges:"
kubectl get challenges -A 2>/dev/null | grep -i oauth || echo "   No challenges found"

echo ""
echo "5️⃣ Check cert-manager logs for oauth2:"
kubectl logs -n cert-manager -l app=cert-manager --tail=100 | grep -i oauth2 || echo "   No oauth2-related logs"

echo ""
echo "6️⃣ Check if HTTP-01 challenge is reachable (port 80):"
echo "   Testing: http://auth.theedgestory.org/.well-known/acme-challenge/test"
curl -v "http://auth.theedgestory.org/.well-known/acme-challenge/test" 2>&1 | grep -E "(HTTP|404|Connection|Trying)" | head -10

echo ""
echo "7️⃣ Check if port 80 is open on server:"
netstat -tuln | grep ":80 " || echo "   Port 80 not listening"

echo ""
echo "8️⃣ Try deleting and recreating Certificate to trigger new attempt:"
echo "   Current Certificate age: $(kubectl get certificate oauth2-proxy-tls -n oauth2-proxy -o jsonpath='{.metadata.creationTimestamp}')"
echo ""
read -p "   Delete and recreate Certificate? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "   Deleting Certificate and CertificateRequest..."
  kubectl delete certificate oauth2-proxy-tls -n oauth2-proxy
  kubectl delete certificaterequest --all -n oauth2-proxy

  echo "   Waiting 5 seconds..."
  sleep 5

  echo "   Recreating Certificate..."
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

  echo "   ✅ Certificate recreated"
  echo ""
  echo "   Waiting 30 seconds for cert-manager to process..."
  sleep 30

  echo "   New status:"
  kubectl get certificate -n oauth2-proxy
  kubectl get certificaterequest -n oauth2-proxy
else
  echo "   Skipped"
fi

echo ""
echo "===================================================="
echo "📋 Summary:"
kubectl get certificate oauth2-proxy-tls -n oauth2-proxy -o wide
