#!/bin/bash

#####################################
# KubeSphere Installation Script
# For: Ubuntu K3s Cluster
# Time: ~15 minutes
#####################################

set -e

echo "========================================="
echo "🚀 KubeSphere Installation Starting"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "ℹ️  $1"
}

# Step 1: Pre-flight checks
echo "=== Step 1: Pre-flight Checks ==="
print_info "Checking Kubernetes cluster..."

if ! kubectl get nodes &> /dev/null; then
    print_error "kubectl not working. Is K3s running?"
    exit 1
fi

print_success "Kubernetes cluster is accessible"

# Check storage class
if kubectl get storageclass local-path &> /dev/null; then
    print_success "Storage class 'local-path' exists"
else
    print_warning "Storage class 'local-path' not found. KubeSphere needs a default storage class."
    exit 1
fi

echo ""

# Step 2: Backup current state
echo "=== Step 2: Creating Backup ==="
print_info "Backing up current cluster state..."

mkdir -p /root/kubesphere-backup
kubectl get all -A -o yaml > /root/kubesphere-backup/all-resources-$(date +%Y%m%d-%H%M%S).yaml
kubectl get secret -A -o yaml > /root/kubesphere-backup/all-secrets-$(date +%Y%m%d-%H%M%S).yaml

print_success "Backup created in /root/kubesphere-backup/"
echo ""

# Step 3: Install KubeSphere
echo "=== Step 3: Installing KubeSphere ==="
print_info "This will take about 10-15 minutes..."
echo ""

print_info "Applying KubeSphere installer..."
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/kubesphere-installer.yaml

sleep 5

print_info "Applying cluster configuration..."
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/cluster-configuration.yaml

print_success "KubeSphere manifests applied"
echo ""

# Step 4: Wait for installation
echo "=== Step 4: Waiting for Installation ==="
print_info "Monitoring installation progress..."
print_warning "This takes 10-15 minutes. Be patient! ☕"
echo ""

# Follow logs
timeout 900 kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f || true

echo ""
echo "=== Step 5: Verifying Installation ==="

# Wait for console pod
print_info "Waiting for KubeSphere console to be ready..."
kubectl wait --for=condition=ready pod -l app=ks-console -n kubesphere-system --timeout=300s || print_warning "Console pod not ready yet"

# Check all KubeSphere pods
print_info "Checking KubeSphere system pods..."
kubectl get pods -n kubesphere-system

echo ""
echo "========================================="
echo "✅ KubeSphere Installation Complete!"
echo "========================================="
echo ""

# Get access information
NODEPORT=$(kubectl get svc ks-console -n kubesphere-system -o jsonpath='{.spec.ports[0].nodePort}')
NODEIP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "📋 Access Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Console URL: http://$NODEIP:$NODEPORT"
echo "   (Use your server's public IP: 46.62.223.198:$NODEPORT)"
echo ""
echo "👤 Username: admin"
echo "🔑 Password: P@88w0rd"
echo ""
echo "⚠️  IMPORTANT: Change the default password immediately!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📝 Next Steps:"
echo "1. Configure HTTPS ingress for KubeSphere console"
echo "2. Enable pluggable components (DevOps, Monitoring, Logging)"
echo "3. Install Strimzi Kafka Operator"
echo "4. Install CloudNativePG PostgreSQL Operator"
echo "5. Deploy your applications"
echo ""
echo "📖 Full migration guide: /root/core-charts/MIGRATION-TO-KUBESPHERE.md"
echo ""

print_success "Installation script completed successfully!"
