#!/bin/bash
# Health Check Script - Verifies all services are running correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== System Health Check ===${NC}"
echo ""

# Function to check URL
check_url() {
    local url=$1
    local name=$2
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302\|401\|403"; then
        echo -e "  ✅ $name: ${GREEN}ONLINE${NC} - $url"
    else
        echo -e "  ❌ $name: ${RED}OFFLINE${NC} - $url"
    fi
}

# Check Kubernetes cluster
echo -e "${YELLOW}Kubernetes Cluster:${NC}"
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "  ✅ Cluster: ${GREEN}CONNECTED${NC}"
else
    echo -e "  ❌ Cluster: ${RED}DISCONNECTED${NC}"
    exit 1
fi

# Check namespaces
echo ""
echo -e "${YELLOW}Namespaces:${NC}"
for ns in argocd infrastructure dev-core prod-core monitoring authentik; do
    if kubectl get namespace $ns >/dev/null 2>&1; then
        echo -e "  ✅ $ns: ${GREEN}EXISTS${NC}"
    else
        echo -e "  ❌ $ns: ${RED}MISSING${NC}"
    fi
done

# Check ArgoCD applications
echo ""
echo -e "${YELLOW}ArgoCD Applications:${NC}"
kubectl get applications -n argocd --no-headers | while read app rest; do
    status=$(kubectl get application $app -n argocd -o jsonpath='{.status.health.status}')
    sync=$(kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}')
    if [ "$status" = "Healthy" ] && [ "$sync" = "Synced" ]; then
        echo -e "  ✅ $app: ${GREEN}Healthy/Synced${NC}"
    else
        echo -e "  ⚠️  $app: ${YELLOW}$status/$sync${NC}"
    fi
done

# Check pods
echo ""
echo -e "${YELLOW}Pod Status:${NC}"
for ns in infrastructure dev-core prod-core monitoring authentik; do
    total=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
    ready=$(kubectl get pods -n $ns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if [ "$total" -eq "$ready" ] && [ "$total" -gt 0 ]; then
        echo -e "  ✅ $ns: ${GREEN}$ready/$total running${NC}"
    elif [ "$total" -eq 0 ]; then
        echo -e "  ⚠️  $ns: ${YELLOW}No pods${NC}"
    else
        echo -e "  ❌ $ns: ${RED}$ready/$total running${NC}"
    fi
done

# Check services
echo ""
echo -e "${YELLOW}Service Endpoints:${NC}"
check_url "https://auth.theedgestory.org" "Authentik SSO"
check_url "https://argo.theedgestory.org" "ArgoCD"
check_url "https://core-pipeline.theedgestory.org/api-docs" "Core Pipeline Prod"
check_url "https://core-pipeline.dev.theedgestory.org/api-docs" "Core Pipeline Dev"
check_url "https://grafana.dev.theedgestory.org" "Grafana"
check_url "https://kafka.theedgestory.org" "Kafka UI"
check_url "https://s3-admin.theedgestory.org" "MinIO Console"
check_url "https://status.theedgestory.org" "Status Page"

# Check infrastructure services
echo ""
echo -e "${YELLOW}Infrastructure Services:${NC}"
# PostgreSQL
if kubectl exec -n infrastructure postgresql-0 -- pg_isready >/dev/null 2>&1; then
    echo -e "  ✅ PostgreSQL: ${GREEN}READY${NC}"
else
    echo -e "  ❌ PostgreSQL: ${RED}NOT READY${NC}"
fi

# Redis
if kubectl exec -n infrastructure redis-master-0 -- redis-cli ping >/dev/null 2>&1; then
    echo -e "  ✅ Redis: ${GREEN}READY${NC}"
else
    echo -e "  ❌ Redis: ${RED}NOT READY${NC}"
fi

# Kafka
if kubectl get kafka -n infrastructure >/dev/null 2>&1; then
    echo -e "  ✅ Kafka: ${GREEN}READY${NC}"
else
    echo -e "  ❌ Kafka: ${RED}NOT READY${NC}"
fi

# Check authentication
echo ""
echo -e "${YELLOW}Authentication:${NC}"
# Check if Google OAuth is configured
if kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -c "SELECT 1 FROM authentik_sources_oauth_oauthsource WHERE provider_type='google'" 2>/dev/null | grep -q "1 row"; then
    echo -e "  ✅ Google OAuth: ${GREEN}CONFIGURED${NC}"
else
    echo -e "  ⚠️  Google OAuth: ${YELLOW}NOT CONFIGURED${NC}"
fi

# Check if access policy exists
if kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -c "SELECT 1 FROM authentik_policies_policy WHERE name LIKE '%dcversus%' OR name LIKE '%Admin%'" 2>/dev/null | grep -q "1 row"; then
    echo -e "  ✅ Access Policy: ${GREEN}CONFIGURED${NC}"
else
    echo -e "  ⚠️  Access Policy: ${YELLOW}NOT CONFIGURED${NC}"
fi

echo ""
echo -e "${GREEN}=== Health Check Complete ===${NC}"