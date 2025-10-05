#!/bin/bash
set -euo pipefail

# KubeSphere v4 Quick Installation (Skip Cleanup)
# Use this if fresh-install.sh cleanup is stuck

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  KubeSphere v4 Quick Install (No Cleanup)                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to wait for pods
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}

    echo -e "${YELLOW}Waiting for pods in ${namespace} (label: ${label})...${NC}"
    kubectl wait --for=condition=ready pod \
        -l "$label" \
        -n "$namespace" \
        --timeout="${timeout}s" 2>/dev/null || true
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}

    echo -e "${YELLOW}Waiting for deployment ${deployment} in ${namespace}...${NC}"
    kubectl rollout status deployment/"$deployment" -n "$namespace" --timeout="${timeout}s" || true
}

# ============================================================================
# PHASE 1: INSTALL KUBESPHERE v4 CORE (3 minutes)
# ============================================================================
echo -e "${GREEN}[1/5] Installing KubeSphere v4.1.3 Core...${NC}"

# Clear Helm cache to avoid corrupted files
echo "  Clearing Helm cache..."
rm -rf ~/.cache/helm/repository/ 2>/dev/null || true
rm -rf ~/.cache/helm/archive/ 2>/dev/null || true

# Clone KubeSphere repository and install from source
echo "  Cloning KubeSphere repository..."
rm -rf /tmp/kubesphere-install
git clone --depth 1 --branch v4.1.3 https://github.com/kubesphere/kubesphere.git /tmp/kubesphere-install

echo "  Installing KubeSphere from chart source..."
helm upgrade --install -n kubesphere-system --create-namespace \
  ks-core /tmp/kubesphere-install/config/ks-core \
  --wait --timeout=5m

# Cleanup
rm -rf /tmp/kubesphere-install

echo "  Waiting for KubeSphere pods..."
sleep 10
wait_for_pods "kubesphere-system" "app=ks-console" 300

echo -e "${GREEN}✓ KubeSphere Core installed${NC}"

# Get admin password
echo ""
echo -e "${YELLOW}KubeSphere Admin Credentials:${NC}"
echo -e "  Username: ${GREEN}admin${NC}"
ADMIN_PASSWORD=$(kubectl get secret -n kubesphere-system ks-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo -e "  Password: ${GREEN}${ADMIN_PASSWORD}${NC}"
echo ""

# Apply HTTPS ingress
echo "  Configuring HTTPS ingress..."
kubectl apply -f k8s/kubesphere-ingress.yaml
sleep 5

echo -e "${GREEN}✓ KubeSphere accessible at: https://kubesphere.dev.theedgestory.org${NC}"
echo ""

# ============================================================================
# PHASE 2: INSTALL OPERATORS (2 minutes)
# ============================================================================
echo -e "${GREEN}[2/5] Installing operators...${NC}"

# CloudNativePG Operator
echo "  Installing CloudNativePG operator..."
kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml \
  --server-side
sleep 5
wait_for_pods "cnpg-system" "app.kubernetes.io/name=cloudnative-pg" 120

# Strimzi Kafka Operator
echo "  Installing Strimzi Kafka operator..."
kubectl create namespace kafka-operator --dry-run=client -o yaml | kubectl apply -f -
helm repo add strimzi https://strimzi.io/charts/ 2>/dev/null || true
helm repo update strimzi
helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka-operator \
  --set watchNamespaces="{infrastructure}" \
  --wait --timeout=3m

echo -e "${GREEN}✓ Operators installed${NC}"
echo ""

# ============================================================================
# PHASE 3: DEPLOY INFRASTRUCTURE (5 minutes)
# ============================================================================
echo -e "${GREEN}[3/5] Deploying infrastructure services...${NC}"

# Create infrastructure namespace
kubectl create namespace infrastructure --dry-run=client -o yaml | kubectl apply -f -

# Deploy PostgreSQL
echo "  Deploying PostgreSQL cluster..."
kubectl apply -f k8s/infrastructure/postgres-cluster.yaml
sleep 10

# Deploy Redis
echo "  Deploying Redis..."
kubectl apply -f k8s/infrastructure/redis.yaml
sleep 5

# Deploy Kafka (takes longest)
echo "  Deploying Kafka cluster (this will take ~3 minutes)..."
kubectl apply -f k8s/infrastructure/kafka-cluster.yaml
sleep 10

# Wait for PostgreSQL
echo "  Waiting for PostgreSQL to be ready..."
kubectl wait cluster/infrastructure-postgres \
  --for=jsonpath='{.status.phase}'='Cluster in healthy state' \
  --timeout=300s -n infrastructure 2>/dev/null || echo "  PostgreSQL may still be initializing..."

# Wait for Redis
echo "  Waiting for Redis to be ready..."
wait_for_deployment "infrastructure" "infrastructure-redis" 120

# Wait for Kafka
echo "  Waiting for Kafka to be ready..."
kubectl wait kafka/infrastructure-kafka \
  --for=condition=Ready \
  --timeout=300s -n infrastructure 2>/dev/null || echo "  Kafka may still be initializing..."

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# ============================================================================
# PHASE 4: CREATE APPLICATION SECRETS (1 minute)
# ============================================================================
echo -e "${GREEN}[4/5] Creating application secrets...${NC}"

# Generate random passwords
PG_DEV_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
PG_PROD_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)

# Wait for PostgreSQL to be fully ready
echo "  Waiting for PostgreSQL to be fully ready..."
sleep 20

# Update PostgreSQL passwords
echo "  Updating PostgreSQL passwords..."
kubectl exec -n infrastructure infrastructure-postgres-1 -- \
  psql -U postgres -c "ALTER USER core_dev_user WITH PASSWORD '$PG_DEV_PASSWORD';" 2>/dev/null || \
  echo "  Will retry password update..."

sleep 5

kubectl exec -n infrastructure infrastructure-postgres-1 -- \
  psql -U postgres -c "ALTER USER core_prod_user WITH PASSWORD '$PG_PROD_PASSWORD';" 2>/dev/null || \
  echo "  Will retry password update..."

# Create secrets for dev-core
kubectl create namespace dev-core --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic core-pipeline-secrets -n dev-core \
  --from-literal=POSTGRES_PASSWORD_DEV="$PG_DEV_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create secrets for prod-core
kubectl create namespace prod-core --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic core-pipeline-secrets -n prod-core \
  --from-literal=POSTGRES_PASSWORD_PROD="$PG_PROD_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Secrets created${NC}"
echo ""

# ============================================================================
# PHASE 5: DEPLOY APPLICATIONS (2 minutes)
# ============================================================================
echo -e "${GREEN}[5/5] Deploying applications...${NC}"

# Deploy dev application
echo "  Deploying core-pipeline (dev)..."
kubectl apply -f k8s/apps/dev/core-pipeline.yaml
sleep 5

# Deploy prod application
echo "  Deploying core-pipeline (prod)..."
kubectl apply -f k8s/apps/prod/core-pipeline.yaml
sleep 5

# Wait for applications
echo "  Waiting for applications to be ready..."
wait_for_deployment "dev-core" "core-pipeline" 180
wait_for_deployment "prod-core" "core-pipeline" 180

echo -e "${GREEN}✓ Applications deployed${NC}"
echo ""

# ============================================================================
# INSTALLATION COMPLETE
# ============================================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Installation Complete! 🎉                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Access Points:${NC}"
echo -e "  KubeSphere: ${GREEN}https://kubesphere.dev.theedgestory.org${NC}"
echo -e "    Username: ${GREEN}admin${NC}"
echo -e "    Password: ${GREEN}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "  Dev App:    ${GREEN}https://core-pipeline.dev.theedgestory.org${NC}"
echo -e "  Prod App:   ${GREEN}https://core-pipeline.theedgestory.org${NC}"
echo ""
echo -e "${YELLOW}Infrastructure Credentials:${NC}"
echo "  PostgreSQL Dev:  core_dev_user / $PG_DEV_PASSWORD"
echo "  PostgreSQL Prod: core_prod_user / $PG_PROD_PASSWORD"
echo ""
echo -e "${YELLOW}Verify Installation:${NC}"
echo "  kubectl get pods -A"
echo "  kubectl get ingress -A"
echo ""
