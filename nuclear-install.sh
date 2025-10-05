#!/bin/bash
set -euo pipefail

# KubeSphere v4 Nuclear Installation
# Complete cluster reset and fresh installation
# WARNING: This will DELETE EVERYTHING in the cluster!

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  NUCLEAR OPTION - COMPLETE CLUSTER RESET                  ║${NC}"
echo -e "${RED}║  This will DELETE EVERYTHING except K3s itself!           ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This script will:${NC}"
echo "  1. Delete ALL namespaces (except kube-system, kube-public, default)"
echo "  2. Remove ALL CRDs"
echo "  3. Clear ALL PVCs and PVs"
echo "  4. Reset Traefik configuration"
echo "  5. Fresh install of cert-manager"
echo "  6. Fresh install of KubeSphere v4"
echo "  7. Fresh install of all infrastructure"
echo ""
read -p "Type 'NUCLEAR' to proceed with complete reset: " -r
if [[ ! $REPLY == "NUCLEAR" ]]; then
    echo "Installation cancelled."
    exit 1
fi

echo ""
echo -e "${GREEN}Starting nuclear reset and installation...${NC}"
echo ""

# ============================================================================
# PHASE 0: PRE-FLIGHT CHECKS (1 minute)
# ============================================================================
echo -e "${BLUE}[0/8] Pre-flight checks...${NC}"

# Set KUBECONFIG if not set
if [ -z "$KUBECONFIG" ]; then
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        echo "  Setting KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
    fi
fi

# Check if kubectl is working
if ! kubectl get nodes &>/dev/null; then
    echo -e "${RED}ERROR: kubectl is not working! Check K3s status.${NC}"
    echo "KUBECONFIG: ${KUBECONFIG:-not set}"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &>/dev/null; then
    echo -e "${YELLOW}Installing Helm...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Check if git is installed
if ! command -v git &>/dev/null; then
    echo -e "${YELLOW}Installing git...${NC}"
    apt-get update && apt-get install -y git
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    echo -e "${YELLOW}Installing jq...${NC}"
    apt-get update && apt-get install -y jq
fi

echo -e "${GREEN}✓ Pre-flight checks complete${NC}"
echo ""

# ============================================================================
# PHASE 1: NUCLEAR CLEANUP (5 minutes)
# ============================================================================
echo -e "${BLUE}[1/8] Nuclear cleanup - removing everything...${NC}"

# Delete all Helm releases in all namespaces
echo "  Removing all Helm releases..."
helm list -A --short | xargs -r -L1 helm uninstall 2>/dev/null || true

# Delete all namespaces except system ones
echo "  Deleting all namespaces..."
kubectl get namespaces -o json | \
  jq -r '.items[] | select(.metadata.name | test("^(kube-system|kube-public|kube-node-lease|default)$") | not) | .metadata.name' | \
  xargs -r -I {} kubectl delete namespace {} --force --grace-period=0 2>/dev/null &

# Give it 30 seconds
sleep 30

# Force remove stuck namespaces by removing finalizers
echo "  Force removing stuck namespaces..."
kubectl get namespaces -o json | \
  jq -r '.items[] | select(.metadata.name | test("^(kube-system|kube-public|kube-node-lease|default)$") | not) | .metadata.name' | \
  xargs -r -I {} kubectl patch namespace {} -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true

# Delete all CRDs (except K3s built-in ones)
echo "  Removing all CRDs (this may take a minute)..."
kubectl get crds -o name | \
  grep -v 'traefik\|helm\|k3s' | \
  xargs -r kubectl delete --ignore-not-found=true --timeout=10s 2>/dev/null &

# Don't wait for CRD deletion to complete
sleep 5

# Delete all PVCs and PVs
echo "  Removing all PVCs and PVs..."
kubectl delete pvc --all -A --force --grace-period=0 2>/dev/null || true
kubectl delete pv --all --force --grace-period=0 2>/dev/null || true

# Clean up any stuck pods
echo "  Removing stuck pods..."
kubectl delete pods --all -A --force --grace-period=0 2>/dev/null || true

# Wait for cleanup to settle
echo "  Waiting for cleanup to complete..."
sleep 10

echo -e "${GREEN}✓ Nuclear cleanup complete${NC}"
echo ""

# ============================================================================
# PHASE 2: RESET TRAEFIK (2 minutes)
# ============================================================================
echo -e "${BLUE}[2/8] Resetting Traefik ingress controller...${NC}"

# Restart Traefik to clear any stuck configurations
kubectl rollout restart deployment traefik -n kube-system 2>/dev/null || true
sleep 10

# Verify Traefik is healthy
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traefik -n kube-system --timeout=120s || \
  echo -e "${YELLOW}Warning: Traefik may still be starting...${NC}"

echo -e "${GREEN}✓ Traefik reset complete${NC}"
echo ""

# ============================================================================
# PHASE 3: INSTALL CERT-MANAGER (2 minutes)
# ============================================================================
echo -e "${BLUE}[3/8] Installing cert-manager...${NC}"

# Wait for cert-manager namespace to be fully deleted if it exists
if kubectl get namespace cert-manager &>/dev/null; then
    echo "  Waiting for old cert-manager namespace to be deleted..."
    kubectl delete namespace cert-manager --wait=true --timeout=60s 2>/dev/null || true
    sleep 10
fi

# Install cert-manager
echo "  Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml

# Wait for cert-manager pods
echo "  Waiting for cert-manager to be ready..."
sleep 20
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s || \
  echo -e "${YELLOW}Warning: cert-manager may still be starting...${NC}"

# Wait a bit more for webhook to be fully ready
sleep 10

# Create Let's Encrypt ClusterIssuer
echo "  Creating Let's Encrypt ClusterIssuer..."
MAX_RETRIES=5
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if cat <<EOF | kubectl apply -f - 2>/dev/null; then
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@theedgestory.org
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "  Waiting for cert-manager webhook... retry $RETRY_COUNT/$MAX_RETRIES"
    sleep 10
done

echo -e "${GREEN}✓ cert-manager installed${NC}"
echo ""

# ============================================================================
# PHASE 4: INSTALL KUBESPHERE v4 (5 minutes)
# ============================================================================
echo -e "${BLUE}[4/8] Installing KubeSphere v4.1.3 Core...${NC}"

# Clear Helm cache
rm -rf ~/.cache/helm/ 2>/dev/null || true

# Clone KubeSphere repository
echo "  Cloning KubeSphere repository..."
rm -rf /tmp/kubesphere-install
git clone --depth 1 --branch v4.1.3 https://github.com/kubesphere/kubesphere.git /tmp/kubesphere-install

echo "  Installing KubeSphere from source..."
helm upgrade --install -n kubesphere-system --create-namespace \
  ks-core /tmp/kubesphere-install/config/ks-core \
  --wait --timeout=10m

# Cleanup
rm -rf /tmp/kubesphere-install

# Wait for KubeSphere pods
echo "  Waiting for KubeSphere pods..."
sleep 20
kubectl wait --for=condition=ready pod -l app=ks-console -n kubesphere-system --timeout=300s || \
  echo -e "${YELLOW}Warning: KubeSphere console may still be starting...${NC}"

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
# PHASE 5: INSTALL OPERATORS (3 minutes)
# ============================================================================
echo -e "${BLUE}[5/8] Installing operators...${NC}"

# CloudNativePG Operator
echo "  Installing CloudNativePG operator..."
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml
sleep 10
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cloudnative-pg -n cnpg-system --timeout=120s || \
  echo -e "${YELLOW}Warning: CloudNativePG may still be starting...${NC}"

# Strimzi Kafka Operator
echo "  Installing Strimzi Kafka operator..."
kubectl create namespace kafka-operator --dry-run=client -o yaml | kubectl apply -f -
helm repo add strimzi https://strimzi.io/charts/ 2>/dev/null || true
helm repo update strimzi
helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka-operator \
  --set watchNamespaces="{infrastructure}" \
  --wait --timeout=5m

echo -e "${GREEN}✓ Operators installed${NC}"
echo ""

# ============================================================================
# PHASE 6: DEPLOY INFRASTRUCTURE (8 minutes)
# ============================================================================
echo -e "${BLUE}[6/8] Deploying infrastructure services...${NC}"

# Create infrastructure namespace
kubectl create namespace infrastructure --dry-run=client -o yaml | kubectl apply -f -

# Deploy PostgreSQL
echo "  Deploying PostgreSQL cluster..."
kubectl apply -f k8s/infrastructure/postgres-cluster.yaml
sleep 15

# Deploy Redis
echo "  Deploying Redis..."
kubectl apply -f k8s/infrastructure/redis.yaml
sleep 10

# Deploy Kafka (takes longest)
echo "  Deploying Kafka cluster (this will take ~5 minutes)..."
kubectl apply -f k8s/infrastructure/kafka-cluster.yaml
sleep 15

# Wait for PostgreSQL
echo "  Waiting for PostgreSQL to be ready..."
kubectl wait cluster/infrastructure-postgres \
  --for=jsonpath='{.status.phase}'='Cluster in healthy state' \
  --timeout=400s -n infrastructure 2>/dev/null || \
  echo -e "${YELLOW}Warning: PostgreSQL may still be initializing...${NC}"

# Wait for Redis
echo "  Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n infrastructure --timeout=120s || \
  echo -e "${YELLOW}Warning: Redis may still be starting...${NC}"

# Wait for Kafka
echo "  Waiting for Kafka to be ready..."
kubectl wait kafka/infrastructure-kafka \
  --for=condition=Ready \
  --timeout=400s -n infrastructure 2>/dev/null || \
  echo -e "${YELLOW}Warning: Kafka may still be initializing...${NC}"

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# ============================================================================
# PHASE 7: CREATE APPLICATION SECRETS (2 minutes)
# ============================================================================
echo -e "${BLUE}[7/8] Creating application secrets...${NC}"

# Generate random passwords
PG_DEV_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
PG_PROD_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)

# Wait for PostgreSQL to be fully ready
echo "  Waiting for PostgreSQL to be fully ready..."
sleep 30

# Update PostgreSQL passwords
echo "  Updating PostgreSQL passwords..."
MAX_RETRIES=5
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl exec -n infrastructure infrastructure-postgres-1 -- \
      psql -U postgres -c "ALTER USER core_dev_user WITH PASSWORD '$PG_DEV_PASSWORD';" 2>/dev/null; then
        echo "    ✓ Dev user password updated"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "    Retry $RETRY_COUNT/$MAX_RETRIES..."
    sleep 10
done

RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl exec -n infrastructure infrastructure-postgres-1 -- \
      psql -U postgres -c "ALTER USER core_prod_user WITH PASSWORD '$PG_PROD_PASSWORD';" 2>/dev/null; then
        echo "    ✓ Prod user password updated"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "    Retry $RETRY_COUNT/$MAX_RETRIES..."
    sleep 10
done

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
# PHASE 8: DEPLOY APPLICATIONS (3 minutes)
# ============================================================================
echo -e "${BLUE}[8/8] Deploying applications...${NC}"

# Deploy dev application
echo "  Deploying core-pipeline (dev)..."
kubectl apply -f k8s/apps/dev/core-pipeline.yaml
sleep 10

# Deploy prod application
echo "  Deploying core-pipeline (prod)..."
kubectl apply -f k8s/apps/prod/core-pipeline.yaml
sleep 10

# Wait for applications
echo "  Waiting for applications to be ready..."
kubectl wait --for=condition=ready pod -l app=core-pipeline -n dev-core --timeout=180s || \
  echo -e "${YELLOW}Warning: Dev app may still be starting...${NC}"
kubectl wait --for=condition=ready pod -l app=core-pipeline -n prod-core --timeout=180s || \
  echo -e "${YELLOW}Warning: Prod app may still be starting...${NC}"

echo -e "${GREEN}✓ Applications deployed${NC}"
echo ""

# ============================================================================
# FINAL VERIFICATION
# ============================================================================
echo -e "${BLUE}Running final verification...${NC}"
echo ""

echo "Namespace status:"
kubectl get namespaces
echo ""

echo "All pods status:"
kubectl get pods -A | grep -E 'kubesphere-system|infrastructure|dev-core|prod-core|cert-manager|cnpg-system|kafka-operator'
echo ""

echo "Ingress status:"
kubectl get ingress -A
echo ""

# ============================================================================
# INSTALLATION COMPLETE
# ============================================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Nuclear Installation Complete! 🎉                        ║${NC}"
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
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Wait ~5 minutes for all services to fully initialize"
echo "  2. Test KubeSphere console access"
echo "  3. Install extensions via Extension Marketplace:"
echo "     - WhizardTelemetry Monitoring"
echo "     - WhizardTelemetry Logging"
echo "  4. Verify application endpoints"
echo ""
echo -e "${YELLOW}Verification Commands:${NC}"
echo "  kubectl get pods -A"
echo "  kubectl get ingress -A"
echo "  curl -k https://core-pipeline.dev.theedgestory.org/health"
echo ""
echo -e "${GREEN}Installation completed at: $(date)${NC}"
echo ""
