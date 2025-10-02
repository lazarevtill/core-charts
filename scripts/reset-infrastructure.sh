#!/bin/bash
set -e

echo "========================================"
echo "INFRASTRUCTURE RESET & REDEPLOY"
echo "========================================"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }

echo ""
echo "=== Step 1: Delete existing infrastructure release ==="
helm uninstall infrastructure -n default 2>/dev/null || print_info "No infrastructure release found"

echo ""
echo "=== Step 2: Clean up failed jobs and pods ==="
kubectl delete job -n default --all 2>/dev/null || true
kubectl delete pod -n default infrastructure-secret-generator-6fzl9 --force --grace-period=0 2>/dev/null || true

echo ""
echo "=== Step 3: Wait for cleanup ==="
sleep 3
print_success "Cleanup complete"

echo ""
echo "=== Step 4: Rebuild Helm dependencies ==="
cd /root/core-charts
helm dependency build charts/infrastructure/postgresql/
helm dependency build charts/infrastructure/redis/
helm dependency build charts/infrastructure/kafka/
helm dependency build charts/infrastructure/
print_success "Dependencies built"

echo ""
echo "=== Step 5: Deploy fresh infrastructure ==="
helm install infrastructure ./charts/infrastructure \
  --namespace default \
  --create-namespace \
  --wait \
  --timeout 15m

print_success "Infrastructure deployed"

echo ""
echo "=== Step 6: Verify deployment ==="
sleep 5

echo ""
echo "📊 Pod Status:"
kubectl get pods -A | grep -E "NAME|postgresql|redis|kafka|init|secret"

echo ""
echo "🔐 PostgreSQL Init Job:"
kubectl logs -n database -l role=init --tail=50 2>/dev/null || echo "No PostgreSQL init logs yet"

echo ""
echo "🔐 Redis ACL Init Job:"
kubectl logs -n redis -l role=init-acl --tail=50 2>/dev/null || echo "No Redis ACL init logs yet"

echo ""
echo "🔑 Secrets Status:"
echo "Dev namespace:"
kubectl get secrets -n dev-core | grep -E "NAME|postgres|redis|kafka" || echo "No secrets yet"
echo ""
echo "Prod namespace:"
kubectl get secrets -n prod-core | grep -E "NAME|postgres|redis|kafka" || echo "No secrets yet"

echo ""
echo "========================================"
echo "✅ INFRASTRUCTURE RESET COMPLETE!"
echo "========================================"
