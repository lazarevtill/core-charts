#!/bin/bash
# Complete Infrastructure Setup Script
# This script sets up all infrastructure services from scratch on a fresh K3s cluster

set -e

echo "=== Core Charts Infrastructure Setup ==="
echo "This script will set up all infrastructure services"
echo ""

# Colors for output
RED='\033[0:31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."

    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed${NC}"; exit 1; }
    command -v git >/dev/null 2>&1 || { echo -e "${RED}git is required but not installed${NC}"; exit 1; }

    # Check kubectl connection
    kubectl cluster-info >/dev/null 2>&1 || { echo -e "${RED}Cannot connect to Kubernetes cluster${NC}"; exit 1; }

    echo -e "${GREEN}✓ Prerequisites met${NC}"
}

# Create TLS secret from Cloudflare Origin Certificate
setup_cloudflare_tls() {
    echo ""
    echo "=== Setting up Cloudflare Origin TLS ==="

    if [ ! -f "/tmp/cloudflare-origin.crt" ] || [ ! -f "/tmp/cloudflare-origin.key" ]; then
        echo -e "${YELLOW}Cloudflare Origin certificate not found at /tmp/cloudflare-origin.{crt,key}${NC}"
        echo "Please place your Cloudflare Origin certificate files there and re-run this script"
        echo "You can get these from: https://dash.cloudflare.com/ -> SSL/TLS -> Origin Server"
        exit 1
    fi

    # Create TLS secret in all namespaces
    for namespace in argocd dev-core prod-core infrastructure monitoring oauth2-proxy status minio; do
        kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
        kubectl create secret tls cloudflare-origin-tls \
            --cert=/tmp/cloudflare-origin.crt \
            --key=/tmp/cloudflare-origin.key \
            -n $namespace \
            --dry-run=client -o yaml | kubectl apply -f -
        echo -e "${GREEN}✓ Created TLS secret in $namespace${NC}"
    done
}

# Setup OAuth2 Proxy with Google OAuth
setup_oauth2() {
    echo ""
    echo "=== Setting up OAuth2 Proxy ==="

    if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
        echo -e "${YELLOW}Google OAuth credentials not set${NC}"
        echo "Please set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET environment variables"
        echo "You can get these from: https://console.cloud.google.com/apis/credentials"
        exit 1
    fi

    # Generate cookie secret
    COOKIE_SECRET=$(openssl rand -base64 32 | tr -d /=+ | cut -c -32)

    # Create OAuth2 Proxy secret
    kubectl create namespace oauth2-proxy --dry-run=client -o yaml | kubectl apply -f -
    kubectl create secret generic oauth2-proxy \
        --from-literal=client-id="$GOOGLE_CLIENT_ID" \
        --from-literal=client-secret="$GOOGLE_CLIENT_SECRET" \
        --from-literal=cookie-secret="$COOKIE_SECRET" \
        -n oauth2-proxy \
        --dry-run=client -o yaml | kubectl apply -f -

    echo -e "${GREEN}✓ OAuth2 Proxy secret created${NC}"
}

# Apply ArgoCD configuration
setup_argocd_config() {
    echo ""
    echo "=== Applying ArgoCD Configuration ==="

    kubectl apply -f config/argocd-cm-patch.yaml
    kubectl apply -f config/argocd-ingress.yaml

    echo -e "${GREEN}✓ ArgoCD configuration applied${NC}"
}

# Apply authorized users configuration
setup_authorized_users() {
    echo ""
    echo "=== Setting up Authorized Users ==="

    kubectl apply -f config/authorized-users.yaml

    echo -e "${GREEN}✓ Authorized users configured${NC}"
}

# Deploy ArgoCD Applications
deploy_argocd_apps() {
    echo ""
    echo "=== Deploying ArgoCD Applications ==="

    kubectl apply -f argocd-apps/

    echo -e "${GREEN}✓ ArgoCD applications deployed${NC}"
    echo "ArgoCD will now sync all applications automatically"
}

# Wait for services to be ready
wait_for_services() {
    echo ""
    echo "=== Waiting for services to be ready ==="

    echo "Waiting for infrastructure pods..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n infrastructure --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n infrastructure --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kafka -n infrastructure --timeout=300s || true

    echo "Waiting for application pods..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=core-pipeline -n dev-core --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=core-pipeline -n prod-core --timeout=300s || true

    echo -e "${GREEN}✓ Services are ready${NC}"
}

# Print access information
print_access_info() {
    echo ""
    echo "=== ================================================= ==="
    echo "=== Infrastructure Setup Complete! ==="
    echo "=== ================================================= ==="
    echo ""
    echo "Services are available at:"
    echo ""
    echo "  ArgoCD:            https://argo.theedgestory.org"
    echo "  Kafka UI:          https://kafka.theedgestory.org"
    echo "  Grafana:           https://grafana.theedgestory.org"
    echo "  MinIO (S3):        https://s3-admin.theedgestory.org"
    echo "  Gatus (Status):    https://status.theedgestory.org"
    echo "  OAuth2 Proxy:      https://auth.theedgestory.org/oauth2/sign_in"
    echo ""
    echo "  Dev App:           https://core-pipeline.dev.theedgestory.org/api-docs"
    echo "  Prod App:          https://core-pipeline.theedgestory.org/api-docs"
    echo ""
    echo "Get ArgoCD admin password:"
    echo "  kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo ""
    echo "Check deployment status:"
    echo "  ./scripts/healthcheck.sh"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    setup_cloudflare_tls
    setup_oauth2
    setup_authorized_users
    setup_argocd_config
    deploy_argocd_apps
    wait_for_services
    print_access_info
}

main
