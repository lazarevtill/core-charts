#!/bin/bash
# Health Check Script
# Checks the status of all infrastructure services

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Infrastructure Health Check ==="
echo ""

# Check cluster connectivity
echo -e "${BLUE}Cluster Connectivity:${NC}"
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
else
    echo -e "${RED}✗ Cannot connect to cluster${NC}"
    exit 1
fi
echo ""

# Check ArgoCD applications
echo -e "${BLUE}ArgoCD Applications:${NC}"
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status" 2>/dev/null || {
    echo -e "${RED}✗ Cannot fetch ArgoCD applications${NC}"
}
echo ""

# Check pods by namespace
check_namespace_pods() {
    local ns=$1
    local name=$2

    echo -e "${BLUE}$name Pods:${NC}"

    if kubectl get namespace $ns >/dev/null 2>&1; then
        local total=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l | tr -d ' ')
        local ready=$(kubectl get pods -n $ns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [ "$total" -eq 0 ]; then
            echo -e "${YELLOW}⚠ No pods found in $ns${NC}"
        elif [ "$ready" -eq "$total" ]; then
            echo -e "${GREEN}✓ All $total pods running${NC}"
        else
            echo -e "${YELLOW}⚠ $ready/$total pods running${NC}"
            kubectl get pods -n $ns --field-selector=status.phase!=Running --no-headers 2>/dev/null
        fi
    else
        echo -e "${RED}✗ Namespace $ns not found${NC}"
    fi
    echo ""
}

# Check infrastructure
check_namespace_pods "infrastructure" "Infrastructure"

# Check applications
check_namespace_pods "dev-core" "Dev Application"
check_namespace_pods "prod-core" "Prod Application"

# Check platform services
check_namespace_pods "argocd" "ArgoCD"
check_namespace_pods "oauth2-proxy" "OAuth2 Proxy"
check_namespace_pods "monitoring" "Monitoring"
check_namespace_pods "minio" "MinIO"
check_namespace_pods "status" "Status (Gatus)"

# Check ingresses
echo -e "${BLUE}Ingresses:${NC}"
kubectl get ingress -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOST:.spec.rules[0].host,PORTS:.status.loadBalancer.ingress[0].ip" 2>/dev/null || {
    echo -e "${RED}✗ Cannot fetch ingresses${NC}"
}
echo ""

# Check TLS secrets
echo -e "${BLUE}TLS Secrets:${NC}"
for ns in argocd dev-core prod-core infrastructure monitoring oauth2-proxy status minio; do
    if kubectl get secret cloudflare-origin-tls -n $ns >/dev/null 2>&1; then
        echo -e "${GREEN}✓ cloudflare-origin-tls present in $ns${NC}"
    else
        echo -e "${RED}✗ cloudflare-origin-tls missing in $ns${NC}"
    fi
done
echo ""

# Check service endpoints
echo -e "${BLUE}Service Endpoints:${NC}"
echo "  ArgoCD:         https://argo.theedgestory.org"
echo "  Kafka UI:       https://kafka.theedgestory.org"
echo "  Grafana:        https://grafana.theedgestory.org"
echo "  MinIO:          https://s3-admin.theedgestory.org"
echo "  Status:         https://status.theedgestory.org"
echo "  Dev App:        https://core-pipeline.dev.theedgestory.org/api-docs"
echo "  Prod App:       https://core-pipeline.theedgestory.org/api-docs"
echo ""

# Summary
echo -e "${BLUE}=== Health Check Complete ===${NC}"
echo ""
echo "For detailed pod logs:"
echo "  kubectl logs -n <namespace> <pod-name>"
echo ""
echo "For ArgoCD sync status:"
echo "  kubectl describe application <app-name> -n argocd"
echo ""
