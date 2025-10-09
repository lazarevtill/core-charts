#!/bin/bash

echo "========================================="
echo "DNS Fix Verification Script"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking DNS records..."
echo ""

# Check each domain
domains=("auth.theedgestory.org" "argo.theedgestory.org" "kafka.theedgestory.org")

for domain in "${domains[@]}"; do
    echo "Checking $domain..."

    # Check DNS resolution
    dns_result=$(nslookup $domain 8.8.8.8 2>/dev/null | grep -A1 "answer:" | tail -1)
    echo "  DNS: $dns_result"

    # Check for CNAME to tunnel
    if echo "$dns_result" | grep -q "cfargotunnel.com"; then
        echo -e "  ${GREEN}✅ Using Cloudflare Tunnel${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Still using direct IP (wait for DNS propagation)${NC}"
    fi

    # Check HTTP response
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --max-time 5 https://$domain 2>/dev/null)

    if [ "$http_code" = "308" ]; then
        echo -e "  ${RED}❌ Redirect loop still present (HTTP $http_code)${NC}"
    elif [ "$http_code" = "200" ] || [ "$http_code" = "302" ] || [ "$http_code" = "303" ]; then
        echo -e "  ${GREEN}✅ Service accessible (HTTP $http_code)${NC}"
    else
        echo -e "  ${YELLOW}⚠️  HTTP $http_code${NC}"
    fi
    echo ""
done

echo "========================================="
echo "Summary:"
echo "========================================="

# Final check
all_good=true
for domain in "${domains[@]}"; do
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -I --max-time 5 https://$domain 2>/dev/null)
    if [ "$http_code" = "308" ]; then
        all_good=false
        break
    fi
done

if $all_good; then
    echo -e "${GREEN}✅ All services are accessible!${NC}"
    echo ""
    echo "You can now access:"
    echo "  • Authentik: https://auth.theedgestory.org"
    echo "    Login: dcversus@gmail.com / authentik-admin-password-2024"
    echo "  • ArgoCD: https://argo.theedgestory.org"
    echo "  • Kafka UI: https://kafka.theedgestory.org"
else
    echo -e "${YELLOW}⚠️  DNS changes may still be propagating.${NC}"
    echo ""
    echo "Please ensure you've added these CNAME records in Cloudflare:"
    echo "  auth  → 6c01bbbf-3488-4182-b17b-3ac004a02d99.cfargotunnel.com"
    echo "  argo  → 6c01bbbf-3488-4182-b17b-3ac004a02d99.cfargotunnel.com"
    echo "  kafka → 6c01bbbf-3488-4182-b17b-3ac004a02d99.cfargotunnel.com"
    echo ""
    echo "Wait 1-2 minutes and run this script again."
fi