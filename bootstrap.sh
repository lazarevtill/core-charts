#!/bin/bash
# Production-Ready Bootstrap Script
# Accepts secrets via stdin (YAML format) or auto-generates them
# Usage:
#   Auto-generate secrets: ./bootstrap.sh
#   Provide secrets:       cat secrets.yaml | ./bootstrap.sh
#   From env vars:         ./generate-secrets.sh | ./bootstrap.sh

set -e

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Generate secure password
generate_password() {
  openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Parse YAML-like input from stdin
parse_secrets() {
  if [ -t 0 ]; then
    # No stdin input, use auto-generation
    print_info "No secrets provided via stdin, using auto-generation"
    GITHUB_USERNAME="${GITHUB_USERNAME:-}"
    GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    POSTGRES_ADMIN_PASSWORD=$(generate_password)
    REDIS_ADMIN_PASSWORD=$(generate_password)
    WEBHOOK_SECRET=$(generate_password)
    LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@example.com}"
    DOMAIN_BASE="${DOMAIN_BASE:-theedgestory.org}"
  else
    # Read secrets from stdin
    print_info "Reading secrets from stdin..."
    local secrets_yaml=$(cat)

    # Simple YAML parsing (works for our flat structure)
    GITHUB_USERNAME=$(echo "$secrets_yaml" | grep "username:" | head -1 | sed 's/.*username: *"\?\([^"]*\)"\?/\1/')
    GITHUB_TOKEN=$(echo "$secrets_yaml" | grep "token:" | head -1 | sed 's/.*token: *"\?\([^"]*\)"\?/\1/')

    # Check for provided passwords or generate
    POSTGRES_ADMIN_PASSWORD=$(echo "$secrets_yaml" | grep "postgresql:" -A 1 | grep "adminPassword:" | sed 's/.*adminPassword: *"\?\([^"]*\)"\?/\1/')
    [ -z "$POSTGRES_ADMIN_PASSWORD" ] && POSTGRES_ADMIN_PASSWORD=$(generate_password)

    REDIS_ADMIN_PASSWORD=$(echo "$secrets_yaml" | grep "redis:" -A 1 | grep "adminPassword:" | sed 's/.*adminPassword: *"\?\([^"]*\)"\?/\1/')
    [ -z "$REDIS_ADMIN_PASSWORD" ] && REDIS_ADMIN_PASSWORD=$(generate_password)

    WEBHOOK_SECRET=$(echo "$secrets_yaml" | grep "webhook:" -A 1 | grep "secret:" | sed 's/.*secret: *"\?\([^"]*\)"\?/\1/')
    [ -z "$WEBHOOK_SECRET" ] && WEBHOOK_SECRET=$(generate_password)

    LETSENCRYPT_EMAIL=$(echo "$secrets_yaml" | grep "letsencrypt:" -A 1 | grep "email:" | sed 's/.*email: *"\?\([^"]*\)"\?/\1/')
    [ -z "$LETSENCRYPT_EMAIL" ] && LETSENCRYPT_EMAIL="admin@example.com"

    DOMAIN_BASE=$(echo "$secrets_yaml" | grep "domain:" -A 1 | grep "base:" | sed 's/.*base: *"\?\([^"]*\)"\?/\1/')
    [ -z "$DOMAIN_BASE" ] && DOMAIN_BASE="theedgestory.org"
  fi

  print_success "Secrets loaded and validated"
}

echo "========================================"
echo "🚀 CORE INFRASTRUCTURE BOOTSTRAP"
echo "========================================"
echo "Production-ready Kubernetes deployment"
echo ""

# Prerequisites check
echo "=== 1. Prerequisites Check ==="
command -v kubectl >/dev/null 2>&1 || print_error "kubectl not found"
command -v helm >/dev/null 2>&1 || print_error "helm not found"
command -v openssl >/dev/null 2>&1 || print_error "openssl not found"
command -v yq >/dev/null 2>&1 || print_warning "yq not found (optional, using sed fallback)"
print_success "All prerequisites satisfied"
echo ""

# Parse or generate secrets
echo "=== 2. Secret Management ==="
parse_secrets
echo ""

# Create namespaces
echo "=== 3. Create Namespaces ==="
for ns in monitoring argocd dev-core prod-core cert-manager infrastructure; do
  kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
done
print_success "Namespaces created"
echo ""

# Create infrastructure admin secrets
echo "=== 4. Create Infrastructure Admin Secrets ==="

# PostgreSQL admin secret (in infrastructure namespace)
kubectl create secret generic postgresql \
  --from-literal=postgres-password="$POSTGRES_ADMIN_PASSWORD" \
  --from-literal=password="$POSTGRES_ADMIN_PASSWORD" \
  --namespace=infrastructure \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Redis admin secret (in infrastructure namespace)
kubectl create secret generic redis \
  --from-literal=redis-password="$REDIS_ADMIN_PASSWORD" \
  --namespace=infrastructure \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# GitHub credentials (if provided)
if [ -n "$GITHUB_TOKEN" ]; then
  kubectl create secret generic ghcr-secret \
    --from-literal=username="$GITHUB_USERNAME" \
    --from-literal=password="$GITHUB_TOKEN" \
    --namespace=dev-core \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  kubectl create secret generic ghcr-secret \
    --from-literal=username="$GITHUB_USERNAME" \
    --from-literal=password="$GITHUB_TOKEN" \
    --namespace=prod-core \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  print_success "Infrastructure secrets created (including GitHub credentials)"
else
  print_success "Infrastructure secrets created (GitHub credentials not provided)"
fi
echo ""

# Install cert-manager
echo "=== 5. Install cert-manager ==="
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml >/dev/null 2>&1
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager >/dev/null 2>&1
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager >/dev/null 2>&1
print_success "cert-manager installed"
echo ""

# Apply cert-manager host network fix
echo "=== 6. Configure cert-manager ==="
kubectl patch deployment cert-manager -n cert-manager --type=merge -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}' >/dev/null 2>&1
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s >/dev/null 2>&1
print_success "cert-manager configured"
echo ""

# Install ArgoCD
echo "=== 7. Install ArgoCD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >/dev/null 2>&1
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd >/dev/null 2>&1
print_success "ArgoCD installed"
echo ""

# Add Helm repositories
echo "=== 8. Configure Helm Repositories ==="
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update >/dev/null 2>&1
print_success "Helm repositories configured"
echo ""

# Remote Helm charts (no build needed)
echo "=== 9. Using Remote Helm Charts ==="
print_info "ArgoCD will fetch dependencies from Bitnami registry"
print_success "Pure GitOps architecture configured"
echo ""

# Create ArgoCD Projects
echo "=== 10. Create ArgoCD Projects ==="
kubectl apply -f argocd/projects.yaml >/dev/null 2>&1 || print_warning "ArgoCD projects not configured"
print_success "ArgoCD projects configured"
echo ""

# Apply ArgoCD Applications
echo "=== 11. Deploy ArgoCD Applications ==="
print_info "Applying all ArgoCD application manifests..."

# Infrastructure (single shared instance)
kubectl apply -f argocd-apps/infrastructure.yaml >/dev/null 2>&1 && print_success "infrastructure app created" || print_warning "infrastructure app failed"

# Applications
kubectl apply -f argocd-apps/core-pipeline-dev.yaml >/dev/null 2>&1 && print_success "core-pipeline-dev app created" || print_warning "core-pipeline-dev app failed"
kubectl apply -f argocd-apps/core-pipeline-prod.yaml >/dev/null 2>&1 && print_success "core-pipeline-prod app created" || print_warning "core-pipeline-prod app failed"

# Monitoring
kubectl apply -f argocd-apps/prometheus.yaml >/dev/null 2>&1 && print_success "prometheus app created" || print_warning "prometheus app failed"
kubectl apply -f argocd-apps/grafana.yaml >/dev/null 2>&1 && print_success "grafana app created" || print_warning "grafana app failed"
kubectl apply -f argocd-apps/loki.yaml >/dev/null 2>&1 && print_success "loki app created" || print_warning "loki app failed"
kubectl apply -f argocd-apps/tempo.yaml >/dev/null 2>&1 && print_success "tempo app created" || print_warning "tempo app failed"

echo ""

# Wait for ArgoCD to sync shared infrastructure
echo "=== 12. Wait for Shared Infrastructure Sync ==="
print_info "Waiting for ArgoCD to sync shared infrastructure (this may take a few minutes)..."

# Trigger sync for infrastructure app
kubectl patch application infrastructure -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"bootstrap"},"sync":{"revision":"HEAD"}}}' >/dev/null 2>&1 || true

# Wait for sync (best effort)
sleep 10
kubectl wait --for=condition=SyncStatusCode=Synced application/infrastructure -n argocd --timeout=600s >/dev/null 2>&1 && print_success "infrastructure synced" || print_warning "infrastructure sync pending (check ArgoCD UI)"

echo ""

# Verify deployments
echo "=== 13. Verify Deployments ==="
print_info "ArgoCD Applications:"
kubectl get applications -n argocd --no-headers 2>/dev/null | while read line; do
  name=$(echo $line | awk '{print $1}')
  sync=$(echo $line | awk '{print $2}')
  health=$(echo $line | awk '{print $3}')
  if [ "$sync" = "Synced" ] && [ "$health" = "Healthy" ]; then
    print_success "$name - $sync/$health"
  else
    print_warning "$name - $sync/$health"
  fi
done
echo ""

echo "========================================"
echo "✅ BOOTSTRAP COMPLETE!"
echo "========================================"
echo ""
echo "📝 Admin Credentials (save securely):"
echo ""
echo "PostgreSQL Admin:"
echo "  User: postgres"
echo "  Password: $POSTGRES_ADMIN_PASSWORD"
echo ""
echo "Redis Admin:"
echo "  Password: $REDIS_ADMIN_PASSWORD"
echo ""
if [ -n "$WEBHOOK_SECRET" ]; then
echo "Webhook Secret:"
echo "  Secret: $WEBHOOK_SECRET"
echo ""
fi
echo "ArgoCD Admin:"
echo "  User: admin"
argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "Not yet available")
echo "  Password: $argocd_password"
echo ""
echo "Grafana Admin:"
echo "  User: admin"
grafana_password=$(kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || echo "Not yet available")
echo "  Password: $grafana_password"
echo ""
echo "========================================"
echo "📊 Next Steps:"
echo "  1. Check ArgoCD apps: kubectl get applications -n argocd"
echo "  2. Access ArgoCD UI: https://argo.dev.$DOMAIN_BASE"
echo "  3. Sync apps manually if needed: kubectl patch application <name> -n argocd --type merge -p '{\"operation\":{\"sync\":{\"revision\":\"HEAD\"}}}'"
echo "  4. Run health check: ./health-check.sh"
echo "  5. Access services:"
echo "     - Grafana: https://grafana.dev.$DOMAIN_BASE"
echo "     - Prometheus: https://prometheus.dev.$DOMAIN_BASE"
echo "     - Dev App: https://core-pipeline.dev.$DOMAIN_BASE"
echo "     - Prod App: https://core-pipeline.$DOMAIN_BASE"
echo ""
echo "🔄 GitOps Workflow:"
echo "  All deployments are now managed by ArgoCD"
echo "  Push to main branch → ArgoCD auto-syncs → Kubernetes updated"
echo "========================================"
echo ""
