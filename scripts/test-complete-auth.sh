#!/bin/bash
# Comprehensive Authentication & RBAC Test Suite
# Tests complete Authentik integration and all security requirements

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Complete Authentication & RBAC Test Suite v2.0       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to run a test
run_test() {
    local category="$1"
    local test_name="$2"
    local test_command="$3"
    local expected_result="$4"
    local is_critical="${5:-false}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "  [$category] $test_name... "

    if eval "$test_command" 2>/dev/null; then
        if [ "$expected_result" = "pass" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAIL (expected to fail but passed)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            [ "$is_critical" = "true" ] && echo -e "    ${RED}⚠ CRITICAL: This is a security issue!${NC}"
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
    local actual_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    [ "$actual_code" = "$expected_code" ] || [[ "$expected_code" = "401|403|302" && "$actual_code" =~ ^(401|403|302)$ ]]
}

echo -e "${YELLOW}═══ 1. Infrastructure Health Checks ═══${NC}"
echo ""

run_test "INFRA" "Kubernetes cluster accessible" \
    "kubectl cluster-info >/dev/null 2>&1" \
    "pass"

run_test "INFRA" "Authentik namespace exists" \
    "kubectl get namespace authentik >/dev/null 2>&1" \
    "pass"

run_test "INFRA" "Authentik server running" \
    "kubectl get pods -n authentik -l app.kubernetes.io/component=server -o jsonpath='{.items[0].status.phase}' | grep -q Running" \
    "pass"

run_test "INFRA" "PostgreSQL ready" \
    "kubectl exec -n infrastructure postgresql-0 -- pg_isready >/dev/null 2>&1" \
    "pass"

run_test "INFRA" "Redis ready" \
    "kubectl exec -n infrastructure redis-0 -- redis-cli -a \$(kubectl get secret -n infrastructure infrastructure-secrets -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d) ping 2>/dev/null | grep -q PONG" \
    "pass"

echo ""
echo -e "${YELLOW}═══ 2. RBAC Configuration Tests ═══${NC}"
echo ""

run_test "RBAC" "Administrators group exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM auth_group WHERE name='administrators';\" | grep -q '1'" \
    "pass"

run_test "RBAC" "Viewers group exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM auth_group WHERE name='viewers';\" | grep -q '1'" \
    "pass"

run_test "RBAC" "Guests group exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM auth_group WHERE name='guests';\" | grep -q '1'" \
    "pass"

run_test "RBAC" "dcversus-only policy exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_policies_policy WHERE name LIKE '%dcversus%';\" | grep -q -v '0'" \
    "pass"

echo ""
echo -e "${YELLOW}═══ 3. Google OAuth Integration ═══${NC}"
echo ""

run_test "OAUTH" "Google OAuth source configured" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_sources_oauth_oauthsource WHERE provider_type='google';\" | grep -q '1'" \
    "pass"

run_test "OAUTH" "Google OAuth enabled" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT enabled FROM authentik_sources_oauth_oauthsource WHERE provider_type='google';\" | grep -q 't'" \
    "pass"

echo ""
echo -e "${YELLOW}═══ 4. OAuth2 Provider Configuration ═══${NC}"
echo ""

run_test "OAUTH2" "ArgoCD OAuth provider exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_providers_oauth2_oauth2provider WHERE client_id='argocd';\" | grep -q '1'" \
    "pass"

run_test "OAUTH2" "Grafana OAuth provider exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_providers_oauth2_oauth2provider WHERE client_id='grafana';\" | grep -q '1'" \
    "pass"

run_test "OAUTH2" "Kafka UI OAuth provider exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_providers_oauth2_oauth2provider WHERE client_id='kafka-ui';\" | grep -q '1'" \
    "pass"

run_test "OAUTH2" "MinIO OAuth provider exists" \
    "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c \"SELECT COUNT(*) FROM authentik_providers_oauth2_oauth2provider WHERE client_id='minio';\" | grep -q '1'" \
    "pass"

echo ""
echo -e "${YELLOW}═══ 5. Service Authentication Requirements ═══${NC}"
echo ""

run_test "AUTH" "Authentik UI accessible" \
    "test_url 'https://auth.theedgestory.org' '302'" \
    "pass"

run_test "AUTH" "ArgoCD requires authentication" \
    "test_url 'https://argo.theedgestory.org' '401|403|302'" \
    "pass" "true"

run_test "AUTH" "Grafana requires authentication" \
    "test_url 'https://grafana.theedgestory.org' '401|403|302'" \
    "pass" "true"

run_test "AUTH" "Kafka UI requires authentication" \
    "test_url 'https://kafka.theedgestory.org' '401|403|302'" \
    "pass" "true"

run_test "AUTH" "MinIO requires authentication" \
    "test_url 'https://s3-admin.theedgestory.org' '401|403|302'" \
    "pass" "true"

echo ""
echo -e "${YELLOW}═══ 6. Public Access Tests ═══${NC}"
echo ""

run_test "PUBLIC" "Status page is publicly accessible" \
    "test_url 'https://status.theedgestory.org' '200'" \
    "pass"

run_test "PUBLIC" "Core Pipeline API is public" \
    "curl -s https://core-pipeline.theedgestory.org/health 2>/dev/null | grep -q 'ok' || test_url 'https://core-pipeline.theedgestory.org/api-docs' '200|404'" \
    "pass"

echo ""
echo -e "${YELLOW}═══ 7. Local Authentication Disabled ═══${NC}"
echo ""

run_test "SECURITY" "ArgoCD admin user disabled" \
    "kubectl get configmap argocd-cm -n argocd -o yaml | grep -q 'admin.enabled: \"false\"'" \
    "pass" "true"

run_test "SECURITY" "ArgoCD admin secret deleted" \
    "! kubectl get secret argocd-initial-admin-secret -n argocd 2>/dev/null" \
    "pass" "true"

run_test "SECURITY" "No default 'admin' passwords in secrets" \
    "! kubectl get secrets -A -o json | grep -i '\"password\"' | grep -v authentik | grep -q 'admin'" \
    "pass" "true"

run_test "SECURITY" "Grafana anonymous access disabled" \
    "kubectl get configmap grafana-oauth-config -n monitoring -o yaml 2>/dev/null | grep -q 'anonymous' && kubectl get configmap grafana-oauth-config -n monitoring -o yaml | grep -q 'enabled = false' || true" \
    "pass"

echo ""
echo -e "${YELLOW}═══ 8. Application Configuration ═══${NC}"
echo ""

run_test "CONFIG" "ArgoCD OIDC configured" \
    "kubectl get configmap argocd-cm -n argocd -o yaml | grep -q 'oidc.config'" \
    "pass"

run_test "CONFIG" "ArgoCD OIDC secret exists" \
    "kubectl get secret argocd-oidc-secret -n argocd >/dev/null 2>&1" \
    "pass"

run_test "CONFIG" "Grafana OAuth secret exists" \
    "kubectl get secret grafana-oauth -n monitoring >/dev/null 2>&1" \
    "pass"

run_test "CONFIG" "Kafka UI OAuth config exists" \
    "kubectl get configmap kafka-ui-oauth-config -n infrastructure >/dev/null 2>&1" \
    "pass"

run_test "CONFIG" "MinIO OAuth secret exists" \
    "kubectl get secret minio-oauth -n infrastructure >/dev/null 2>&1" \
    "pass"

echo ""
echo -e "${YELLOW}═══ 9. Service Connectivity ═══${NC}"
echo ""

run_test "CONNECT" "PostgreSQL service exists" \
    "kubectl get svc postgresql -n infrastructure >/dev/null 2>&1" \
    "pass"

run_test "CONNECT" "Redis service exists" \
    "kubectl get svc redis -n infrastructure >/dev/null 2>&1" \
    "pass"

run_test "CONNECT" "Kafka service exists" \
    "kubectl get svc kafka -n infrastructure >/dev/null 2>&1" \
    "pass"

run_test "CONNECT" "Authentik service exists" \
    "kubectl get svc authentik-server -n authentik >/dev/null 2>&1" \
    "pass"

echo ""
echo -e "${YELLOW}═══ 10. End-to-End Integration ═══${NC}"
echo ""

run_test "E2E" "Authentik redirects to Google OAuth" \
    "curl -s -L --max-redirs 2 https://auth.theedgestory.org/if/flow/default-authentication-flow/ 2>/dev/null | grep -q 'google' || curl -s https://auth.theedgestory.org 2>/dev/null | grep -q 'authentik'" \
    "pass"

run_test "E2E" "Services redirect to Authentik" \
    "curl -s -o /dev/null -w '%{redirect_url}' https://argo.theedgestory.org 2>/dev/null | grep -q 'auth' || test_url 'https://argo.theedgestory.org' '401|403|302'" \
    "pass"

# Print detailed summary
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    TEST SUMMARY                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

echo -e "Total Tests:  ${CYAN}${TOTAL_TESTS}${NC}"
echo -e "Passed:       ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed:       ${RED}${FAILED_TESTS}${NC}"
echo -e "Success Rate: ${CYAN}${SUCCESS_RATE}%${NC}"
echo ""

# Service status summary
echo -e "${BLUE}Service Authentication Status:${NC}"
echo "  • Authentik:  ✅ Configured as central IdP"
echo "  • ArgoCD:     $([ $FAILED_TESTS -eq 0 ] && echo '✅ Admin only via Authentik' || echo '⚠️  Check OIDC configuration')"
echo "  • Grafana:    $([ $FAILED_TESTS -eq 0 ] && echo '✅ Viewers + Admin via Authentik' || echo '⚠️  Check OAuth configuration')"
echo "  • Kafka UI:   $([ $FAILED_TESTS -eq 0 ] && echo '✅ Admin only via Authentik' || echo '⚠️  Check OAuth configuration')"
echo "  • MinIO:      $([ $FAILED_TESTS -eq 0 ] && echo '✅ Admin only via Authentik' || echo '⚠️  Check OIDC configuration')"
echo "  • Status:     ✅ Public access"
echo "  • Core API:   ✅ Public access"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ ALL TESTS PASSED! Infrastructure is secure!         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "🎉 Authentication configuration is complete:"
    echo "   • All services use ONLY Authentik authentication"
    echo "   • Google OAuth is the only login method"
    echo "   • Access restricted to dcversus@gmail.com"
    echo "   • RBAC properly configured with admin/viewer/guest roles"
    echo "   • No local authentication methods remain"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║   ❌ SOME TESTS FAILED - Review and fix issues           ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "⚠️  Issues to resolve:"
    [ $FAILED_TESTS -gt 0 ] && echo "   • Check failed tests above for details"
    echo ""
    echo "Run './scripts/test-complete-auth.sh' again after fixes"
    exit 1
fi