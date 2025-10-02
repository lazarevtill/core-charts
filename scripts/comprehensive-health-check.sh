#!/bin/bash

echo "========================================"
echo "COMPREHENSIVE HEALTH CHECK"
echo "========================================"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_endpoint() {
  local url=$1
  local desc=$2

  echo -n "Checking $desc: "

  # Try to get HTTP status code
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)

  if [ "$status" = "200" ]; then
    echo -e "${GREEN}✓ OK (200)${NC}"
  elif [ "$status" = "301" ] || [ "$status" = "302" ] || [ "$status" = "307" ] || [ "$status" = "308" ]; then
    echo -e "${YELLOW}⚠ REDIRECT ($status)${NC}"
  elif [ "$status" = "401" ] || [ "$status" = "403" ]; then
    echo -e "${YELLOW}⚠ AUTH REQUIRED ($status)${NC}"
  elif [ -z "$status" ] || [ "$status" = "000" ]; then
    echo -e "${RED}✗ TIMEOUT/UNREACHABLE${NC}"
  else
    echo -e "${RED}✗ ERROR ($status)${NC}"
  fi
}

echo ""
echo "=== ArgoCD ==="
check_endpoint "https://argo.dev.theedgestory.org" "HTTPS root"
check_endpoint "http://argo.dev.theedgestory.org" "HTTP root (should redirect)"
check_endpoint "https://argo.dev.theedgestory.org/api/version" "API endpoint"

echo ""
echo "=== Core Pipeline Dev ==="
check_endpoint "https://core-pipeline.dev.theedgestory.org" "HTTPS root"
check_endpoint "http://core-pipeline.dev.theedgestory.org" "HTTP root (should redirect)"
check_endpoint "https://core-pipeline.dev.theedgestory.org/api-docs" "API docs"
check_endpoint "https://core-pipeline.dev.theedgestory.org/health" "Health endpoint"

echo ""
echo "=== Core Pipeline Prod ==="
check_endpoint "https://core-pipeline.theedgestory.org" "HTTPS root"
check_endpoint "http://core-pipeline.theedgestory.org" "HTTP root (should redirect)"
check_endpoint "https://core-pipeline.theedgestory.org/api-docs" "API docs"
check_endpoint "https://core-pipeline.theedgestory.org/health" "Health endpoint"

echo ""
echo "=== Kafka UI ==="
check_endpoint "https://kafka.dev.theedgestory.org" "HTTPS root"
check_endpoint "http://kafka.dev.theedgestory.org" "HTTP root (should redirect)"

echo ""
echo "=== Grafana ==="
check_endpoint "https://grafana.dev.theedgestory.org" "HTTPS root"
check_endpoint "http://grafana.dev.theedgestory.org" "HTTP root (should redirect)"
check_endpoint "https://grafana.dev.theedgestory.org/api/health" "API health"

echo ""
echo "=== Prometheus ==="
check_endpoint "https://prometheus.dev.theedgestory.org" "HTTPS root"
check_endpoint "http://prometheus.dev.theedgestory.org" "HTTP root (should redirect)"
check_endpoint "https://prometheus.dev.theedgestory.org/api/v1/status/config" "API endpoint"

echo ""
echo "========================================"
echo "CERTIFICATE STATUS"
echo "========================================"
kubectl get certificate -A

echo ""
echo "========================================"
echo "POD STATUS"
echo "========================================"
kubectl get pods -A | grep -E "NAME|argocd|core-pipeline|kafka|grafana|prometheus|redis|postgres"

echo ""
echo "========================================"
echo "HEALTH CHECK COMPLETE"
echo "========================================"
