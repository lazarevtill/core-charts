#!/bin/bash
set -e

echo "========================================"
echo "INFRASTRUCTURE BOOTSTRAP SETUP"
echo "========================================"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Generate secure password
generate_password() {
  openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

echo ""
echo "=== Prerequisites Check ==="
command -v kubectl >/dev/null 2>&1 || { print_error "kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { print_error "helm not found"; exit 1; }
command -v openssl >/dev/null 2>&1 || { print_error "openssl not found"; exit 1; }
print_success "All prerequisites satisfied"

echo ""
echo "=== Generate Secrets ==="
POSTGRES_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)
CORE_DEV_DB_PASSWORD=$(generate_password)
CORE_PROD_DB_PASSWORD=$(generate_password)
ARGOCD_ADMIN_PASSWORD=$(generate_password)
GRAFANA_ADMIN_PASSWORD=$(generate_password)

print_success "Generated all passwords"

echo ""
echo "=== Create Namespaces ==="
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace redis --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev-core --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod-core --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
print_success "Namespaces created"

echo ""
echo "=== Create Infrastructure Secrets ==="

# PostgreSQL secret
kubectl create secret generic postgresql \
  --from-literal=postgres-password=$POSTGRES_PASSWORD \
  --from-literal=password=$POSTGRES_PASSWORD \
  --namespace=database \
  --dry-run=client -o yaml | kubectl apply -f -

# Redis secret
kubectl create secret generic redis \
  --from-literal=redis-password=$REDIS_PASSWORD \
  --namespace=redis \
  --dry-run=client -o yaml | kubectl apply -f -

# All-credentials secret (used by applications)
kubectl create secret generic all-credentials \
  --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=REDIS_PASSWORD=$REDIS_PASSWORD \
  --from-literal=DB_PASSWORD=$CORE_DEV_DB_PASSWORD \
  --from-literal=DB_USERNAME=core_user \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

# Copy to app namespaces
kubectl get secret all-credentials -n default -o yaml | \
  sed 's/namespace: default/namespace: dev-core/' | kubectl apply -f -
kubectl get secret all-credentials -n default -o yaml | \
  sed 's/namespace: default/namespace: prod-core/' | kubectl apply -f -

print_success "Infrastructure secrets created"

echo ""
echo "=== Install cert-manager ==="
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
print_success "cert-manager installed"

echo ""
echo "=== Apply cert-manager host network fix ==="
kubectl patch deployment cert-manager -n cert-manager --type=merge -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
print_success "cert-manager configured"

echo ""
echo "=== Install ArgoCD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
print_success "ArgoCD installed"

echo ""
echo "=== Deploy Infrastructure Helm Charts ==="
# Add helm repos if needed
helm repo add bitnami https://charts.bitnami.com/bitnami || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update

# Deploy infrastructure
helm upgrade --install infrastructure ./charts/infrastructure \
  --namespace default \
  --create-namespace \
  --wait \
  --timeout 10m

print_success "Infrastructure deployed"

echo ""
echo "=== Apply ArgoCD Applications ==="
kubectl apply -f argocd-apps/ -n argocd || true
print_success "ArgoCD applications configured"

echo ""
echo "========================================"
echo "SETUP COMPLETE!"
echo "========================================"

echo ""
echo "📝 Save these credentials securely:"
echo ""
echo "PostgreSQL Admin:"
echo "  User: postgres"
echo "  Password: $POSTGRES_PASSWORD"
echo ""
echo "Redis:"
echo "  Password: $REDIS_PASSWORD"
echo ""
echo "ArgoCD Admin:"
echo "  User: admin"
echo "  Password: (run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo ""
echo "Grafana Admin:"
echo "  User: admin"  
echo "  Password: (run: kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
echo ""
echo "Core Pipeline Dev DB:"
echo "  User: core_user"
echo "  Password: $CORE_DEV_DB_PASSWORD"
echo ""
echo "========================================"
echo "Next steps:"
echo "  1. Run: ./health-check.sh"
echo "  2. Access ArgoCD: https://argo.dev.theedgestory.org"
echo "  3. Access Grafana: https://grafana.dev.theedgestory.org"
echo "========================================"
