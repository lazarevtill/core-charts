#!/bin/bash
set -e

echo "🔐 Deploying Google OAuth for All Services"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on server with kubectl access
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ Error: Cannot connect to Kubernetes cluster${NC}"
    echo "This script must be run on the server with kubectl access"
    echo ""
    echo "To run on server:"
    echo "  ssh -i ~/.ssh/hetzner root@46.62.223.198"
    echo "  cd /root/core-charts"
    echo "  git pull origin main"
    echo "  bash deploy-oauth.sh"
    exit 1
fi

echo -e "${GREEN}✅ Connected to Kubernetes cluster${NC}"
echo ""

# Function to check if OAuth secret exists
check_oauth_secret() {
    local namespace=$1
    if kubectl get secret google-oauth -n $namespace &>/dev/null; then
        echo -e "${GREEN}✓${NC} OAuth secret exists in namespace: $namespace"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}  OAuth secret NOT found in namespace: $namespace"
        return 1
    fi
}

# Check for OAuth secrets
echo "🔍 Checking for OAuth secrets..."
echo ""

SECRETS_FOUND=true
check_oauth_secret monitoring || SECRETS_FOUND=false
check_oauth_secret minio || SECRETS_FOUND=false
check_oauth_secret kubero || SECRETS_FOUND=false

echo ""

if [ "$SECRETS_FOUND" = false ]; then
    echo -e "${YELLOW}⚠️  WARNING: OAuth secrets not found!${NC}"
    echo ""
    echo "To create OAuth secrets, run:"
    echo "  export GOOGLE_CLIENT_ID='your-client-id'"
    echo "  export GOOGLE_CLIENT_SECRET='your-client-secret'"
    echo "  ./auth/setup-google-oauth.sh"
    echo ""
    echo "Or continue without OAuth (services will work but without Google authentication)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    echo ""
fi

# Deploy Grafana with OAuth
echo "📊 Deploying Grafana with OAuth support..."
if kubectl apply -f monitoring/deploy-grafana.yaml; then
    echo -e "${GREEN}✅ Grafana deployment applied${NC}"
else
    echo -e "${RED}❌ Failed to apply Grafana deployment${NC}"
fi
echo ""

# Deploy Kafka UI with OAuth
echo "📨 Deploying Kafka UI with OAuth support..."
if kubectl apply -f monitoring/deploy-kafka-ui-oauth.yaml; then
    echo -e "${GREEN}✅ Kafka UI deployment applied${NC}"
else
    echo -e "${RED}❌ Failed to apply Kafka UI deployment${NC}"
fi
echo ""

# Deploy MinIO OAuth configuration
echo "💾 Applying MinIO OAuth configuration..."
if kubectl apply -f minio/minio-oauth-config.yaml; then
    echo -e "${GREEN}✅ MinIO OAuth config applied${NC}"
else
    echo -e "${RED}❌ Failed to apply MinIO OAuth config${NC}"
fi
echo ""

# Deploy Kubero OAuth configuration
echo "🔧 Applying Kubero OAuth configuration..."
if kubectl apply -f kubero/kubero-oauth.yaml; then
    echo -e "${GREEN}✅ Kubero OAuth config applied${NC}"
else
    echo -e "${RED}❌ Failed to apply Kubero OAuth config${NC}"
fi
echo ""

# Restart services
echo "🔄 Restarting services to apply OAuth changes..."
echo ""

echo "  → Restarting Grafana..."
kubectl rollout restart statefulset/grafana -n monitoring 2>/dev/null || echo -e "${YELLOW}    ⚠ Grafana may need manual restart${NC}"

echo "  → Waiting for Kafka UI to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/kafka-ui -n monitoring 2>/dev/null || echo -e "${YELLOW}    ⚠ Kafka UI deployment timeout (may still be deploying)${NC}"

echo "  → Restarting MinIO tenant..."
kubectl rollout restart statefulset/minio-tenant-pool-0 -n minio 2>/dev/null || echo -e "${YELLOW}    ⚠ MinIO may need manual restart${NC}"

echo "  → Restarting Kubero..."
kubectl rollout restart deployment/kubero -n kubero 2>/dev/null || echo -e "${YELLOW}    ⚠ Kubero may need manual restart${NC}"

echo ""
echo "⏳ Waiting for services to be ready..."
echo ""

# Wait for services
sleep 5

# Check pod status
echo "📊 Service Status:"
echo ""

echo "Grafana:"
kubectl get pods -n monitoring -l app=grafana -o wide | grep -v NAME | head -3 || echo "  No pods found"

echo ""
echo "Kafka UI:"
kubectl get pods -n monitoring -l app=kafka-ui -o wide | grep -v NAME | head -3 || echo "  No pods found"

echo ""
echo "MinIO:"
kubectl get pods -n minio -l app=minio -o wide | grep -v NAME | head -3 || echo "  No pods found"

echo ""
echo "Kubero:"
kubectl get pods -n kubero -l app=kubero -o wide | grep -v NAME | head -3 || echo "  No pods found"

echo ""
echo "🌐 Service URLs:"
echo ""
echo "  📊 Grafana:     https://grafana.theedgestory.org"
echo "  📨 Kafka UI:    https://kafka.theedgestory.org"
echo "  💾 MinIO Admin: https://s3-admin.theedgestory.org"
echo "  🔧 Kubero:      https://dev.theedgestory.org"
echo ""

if [ "$SECRETS_FOUND" = true ]; then
    echo -e "${GREEN}✅ OAuth deployment complete!${NC}"
    echo ""
    echo "🔐 Google OAuth is now enabled on all services"
    echo "   Visit each service and look for 'Sign in with Google' option"
else
    echo -e "${YELLOW}⚠️  Deployments applied but OAuth secrets not configured${NC}"
    echo ""
    echo "To enable Google OAuth:"
    echo "  1. Create OAuth client: https://console.cloud.google.com/apis/credentials"
    echo "  2. Run: ./auth/setup-google-oauth.sh"
    echo "  3. Re-run this script: ./deploy-oauth.sh"
fi

echo ""
echo "📖 For detailed documentation, see: auth/OAUTH_DEPLOYMENT_GUIDE.md"
echo ""
