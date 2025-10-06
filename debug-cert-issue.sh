#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "🔍 Certificate Issuance Debug"
echo "============================="
echo ""

echo "1️⃣ CertificateRequest status:"
kubectl get certificaterequest -n oauth2-proxy
echo ""
kubectl describe certificaterequest -n oauth2-proxy | tail -30

echo ""
echo "2️⃣ Challenge status (if using HTTP-01):"
kubectl get challenges -n oauth2-proxy 2>/dev/null || echo "   No challenges found"

echo ""
echo "3️⃣ cert-manager logs (last 50 lines):"
kubectl logs -n cert-manager -l app=cert-manager --tail=50

echo ""
echo "4️⃣ ClusterIssuer status:"
kubectl describe clusterissuer letsencrypt-prod | tail -20

echo ""
echo "5️⃣ Check if auth.theedgestory.org resolves:"
nslookup auth.theedgestory.org || host auth.theedgestory.org || echo "DNS lookup failed"

echo ""
echo "6️⃣ Check HTTP-01 challenge endpoint (if applicable):"
curl -v http://auth.theedgestory.org/.well-known/acme-challenge/test 2>&1 | grep -E "(HTTP|Location|404)" || true

echo ""
echo "============================="
echo "Common issues:"
echo "  1. DNS not resolving to correct IP"
echo "  2. HTTP-01 challenge can't reach server (firewall/port 80)"
echo "  3. ClusterIssuer misconfigured"
echo "  4. Rate limiting from Let's Encrypt"
