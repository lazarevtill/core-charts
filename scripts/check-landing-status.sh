#!/bin/bash
# Check landing page deployment status and diagnose TLS issues

set -e

echo "🔍 Checking Landing Page Status..."
echo ""

echo "1️⃣ Checking pods..."
kubectl get pods -n default -l app=landing-page
echo ""

echo "2️⃣ Checking service..."
kubectl get svc -n default landing-page
echo ""

echo "3️⃣ Checking ingress..."
kubectl get ingress -n default landing-page
echo ""

echo "4️⃣ Checking TLS certificates..."
kubectl get certificate -n default
echo ""

echo "5️⃣ Certificate details (if exists)..."
kubectl describe certificate landing-page-tls -n default 2>/dev/null || echo "Certificate not found"
echo ""

echo "6️⃣ Checking cert-manager challenges..."
kubectl get challenges -n default 2>/dev/null || echo "No challenges found"
echo ""

echo "7️⃣ Testing internal connectivity..."
POD=$(kubectl get pods -n default -l app=landing-page -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
    echo "Testing nginx inside pod $POD..."
    kubectl exec -n default $POD -- curl -s -I http://localhost/ | head -5
else
    echo "No pods found"
fi
echo ""

echo "8️⃣ DNS check..."
echo "theedgestory.org resolves to:"
dig +short theedgestory.org
echo ""

echo "✅ Status check complete!"
echo ""
echo "🔧 If certificates are failing:"
echo "   1. Check Cloudflare DNS settings (should be 'DNS only', not proxied)"
echo "   2. Temporarily disable Cloudflare proxy (orange cloud → gray)"
echo "   3. Wait 2-3 minutes for Let's Encrypt to validate domain"
echo "   4. Re-enable Cloudflare proxy after certificates are issued"
