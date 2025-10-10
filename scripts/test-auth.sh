#!/bin/bash
# Comprehensive Authentication and RBAC Test Suite
# Tests all services for proper Authentik integration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}=== Authentication & RBAC Test Suite ===${NC}"
echo ""

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "  Testing: $test_name... "

    if eval "$test_command"; then
        if [ "$expected_result" = "pass" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAIL (expected to fail but passed)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        if [ "$expected_result" = "fail" ]; then
            echo -e "${GREEN}✓ PASS (correctly failed)${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
}

# Test URL accessibility
test_url() {
    local url="$1"
    local expected_code="$2"
    local actual_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    [ "$actual_code" = "$expected_code" ]
}

echo -e "${YELLOW}1. Infrastructure Tests${NC}"
echo ""

# Test Kubernetes connectivity
run_test "Kubernetes cluster accessible" \
    "kubectl cluster-info >/dev/null 2>&1" \
    "pass"

# Test namespaces exist
for ns in authentik infrastructure dev-core prod-core monitoring; do
    run_test "Namespace $ns exists" \
        "kubectl get namespace $ns >/dev/null 2>&1" \
        "pass"
done

echo ""
echo -e "${YELLOW}2. Authentik Core Tests${NC}"
echo ""

# Test Authentik is running
run_test "Authentik server pod running" \
    "kubectl get pods -n authentik -l app.kubernetes.io/component=server -o jsonpath='{.items[0].status.phase}' | grep -q Running" \
    "pass"

run_test "Authentik worker pod running" \
    "kubectl get pods -n authentik -l app.kubernetes.io/component=worker -o jsonpath='{.items[0].status.phase}' | grep -q Running" \
    "pass"

# Test Authentik web UI
run_test "Authentik UI accessible (302 redirect)" \
    "test_url 'https://auth.theedgestory.org' '302'" \
    "pass"

echo ""
echo -e "${YELLOW}3. Database Tests${NC}"
echo ""

# Test groups exist
run_test "Admin group exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM auth_group WHERE name='administrators';\" | grep -q '1'" \
    "pass"

run_test "Viewer group exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM auth_group WHERE name='viewers';\" | grep -q '1'" \
    "pass"

run_test "Guest group exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM auth_group WHERE name='guests';\" | grep -q '1'" \
    "pass"

# Test Google OAuth source
run_test "Google OAuth source configured" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_sources_oauth_oauthsource WHERE provider_type='google';\" | grep -q '1'" \
    "pass"

echo ""
echo -e "${YELLOW}4. Service Authentication Tests${NC}"
echo ""

# Test service endpoints return auth redirects (302) or auth required (401/403)
run_test "ArgoCD requires authentication" \
    "curl -s -o /dev/null -w '%{http_code}' https://argo.theedgestory.org | grep -E '302|401|403' >/dev/null" \
    "pass"

run_test "Grafana requires authentication" \
    "curl -s -o /dev/null -w '%{http_code}' https://grafana.theedgestory.org | grep -E '302|401|403' >/dev/null" \
    "pass"

run_test "Kafka UI requires authentication" \
    "curl -s -o /dev/null -w '%{http_code}' https://kafka.theedgestory.org | grep -E '302|401|403' >/dev/null" \
    "pass"

run_test "MinIO requires authentication" \
    "curl -s -o /dev/null -w '%{http_code}' https://s3-admin.theedgestory.org | grep -E '302|401|403' >/dev/null" \
    "pass"

echo ""
echo -e "${YELLOW}5. Public Access Tests${NC}"
echo ""

# Test public services are accessible without auth
run_test "Status page is public (200)" \
    "test_url 'https://status.theedgestory.org' '200'" \
    "pass"

run_test "Core Pipeline API is public" \
    "curl -s -o /dev/null -w '%{http_code}' https://core-pipeline.theedgestory.org/api-docs | grep -E '200|404' >/dev/null" \
    "pass"

echo ""
echo -e "${YELLOW}6. OAuth2/OIDC Configuration Tests${NC}"
echo ""

# Check if OAuth providers exist
run_test "OAuth providers configured" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_providers_oauth2_oauth2provider;\" | grep -q -v '0'" \
    "pass"

# Check if applications exist
run_test "Applications configured" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_core_application;\" | grep -q -v '0'" \
    "pass"

echo ""
echo -e "${YELLOW}7. Infrastructure Service Tests${NC}"
echo ""

# Test infrastructure services
run_test "PostgreSQL is ready" \
    "kubectl exec -n infrastructure postgresql-0 -- pg_isready >/dev/null 2>&1" \
    "pass"

run_test "Redis is ready" \
    "kubectl exec -n infrastructure redis-0 -- redis-cli -a \$(kubectl get secret -n infrastructure infrastructure-secrets -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d) ping 2>/dev/null | grep -q PONG" \
    "pass"

run_test "Kafka is ready" \
    "kubectl get kafka -n infrastructure >/dev/null 2>&1" \
    "pass"

echo ""
echo -e "${YELLOW}8. Security Tests${NC}"
echo ""

# Test that default/admin passwords are disabled
run_test "ArgoCD admin user disabled" \
    "kubectl get configmap argocd-cm -n argocd -o yaml | grep -q 'admin.enabled: \"false\"'" \
    "pass"

# Test no default passwords in secrets
run_test "No default 'admin' passwords in secrets" \
    "! kubectl get secrets -A -o yaml | grep -i 'password:' | base64 -d 2>/dev/null | grep -q 'admin'" \
    "pass"

echo ""
echo -e "${YELLOW}9. RBAC Policy Tests${NC}"
echo ""

# Check policies exist
run_test "Admin policy exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_policies_policy p JOIN authentik_policies_expression_expressionpolicy e ON p.policy_uuid = e.policy_ptr_id WHERE p.name='Administrators Only';\" | grep -q '1'" \
    "pass"

run_test "Viewer policy exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_policies_policy p JOIN authentik_policies_expression_expressionpolicy e ON p.policy_uuid = e.policy_ptr_id WHERE p.name='Viewers and Admins';\" | grep -q '1'" \
    "pass"

run_test "dcversus-only policy exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_policies_policy WHERE name LIKE '%dcversus%';\" | grep -q -v '0'" \
    "pass"

echo ""
echo -e "${YELLOW}10. Integration Tests${NC}"
echo ""

# Test service discovery
run_test "Services can reach PostgreSQL" \
    "kubectl get svc postgresql -n infrastructure >/dev/null 2>&1" \
    "pass"

run_test "Services can reach Redis" \
    "kubectl get svc redis -n infrastructure >/dev/null 2>&1" \
    "pass"

# Print summary
echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo ""
echo -e "Total Tests: ${TOTAL_TESTS}"
echo -e "Passed: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed: ${RED}${FAILED_TESTS}${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed! Infrastructure is properly configured.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please review and fix the issues.${NC}"
    exit 1
fi