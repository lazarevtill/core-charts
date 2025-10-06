#!/bin/bash
# Clean up old Let's Encrypt certificates for landing page
# Since we're using Cloudflare Tunnel, these are not needed

set -e

echo "🧹 Cleaning up old Let's Encrypt certificates..."
echo ""

# Delete certificate resources
echo "Deleting certificate resources..."
kubectl delete certificate landing-page-tls -n default 2>/dev/null && echo "✅ Deleted landing-page-tls certificate" || echo "⚠️  Certificate landing-page-tls not found"
kubectl delete certificate landing-page-www-tls -n default 2>/dev/null && echo "✅ Deleted landing-page-www-tls certificate" || echo "⚠️  Certificate landing-page-www-tls not found"

# Delete certificate secrets
echo ""
echo "Deleting certificate secrets..."
kubectl delete secret landing-page-tls -n default 2>/dev/null && echo "✅ Deleted landing-page-tls secret" || echo "⚠️  Secret landing-page-tls not found"
kubectl delete secret landing-page-www-tls -n default 2>/dev/null && echo "✅ Deleted landing-page-www-tls secret" || echo "⚠️  Secret landing-page-www-tls not found"

# Delete challenges
echo ""
echo "Deleting pending challenges..."
kubectl delete challenges --all -n default 2>/dev/null && echo "✅ Deleted challenges" || echo "⚠️  No challenges found"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Now redeploy the landing page:"
echo "  bash scripts/deploy-landing.sh"
