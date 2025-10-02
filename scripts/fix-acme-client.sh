#!/bin/bash
set -e

echo "========================================"
echo "CERT-MANAGER ACME CLIENT FIX"
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
echo "=== Diagnosis ==="
print_info "Checking cert-manager status..."
kubectl get pods -n cert-manager
kubectl get clusterissuer

echo ""
echo "=== Step 1: Restart cert-manager pod ==="
print_info "Deleting cert-manager pod to force clean restart..."
kubectl delete pod -n cert-manager -l app=cert-manager
sleep 5
kubectl wait --for=condition=ready --timeout=120s pod -n cert-manager -l app=cert-manager
print_success "cert-manager pod restarted"

echo ""
echo "=== Step 2: Check ACME registration ==="
print_info "Verifying ClusterIssuer status..."
kubectl get clusterissuer letsencrypt-prod -o jsonpath='{.status.conditions[0].message}'
echo ""

echo ""
echo "=== Step 3: Delete stuck challenges ==="
print_info "Removing old challenges that may be blocking..."
kubectl get challenge -A --no-headers 2>/dev/null | while read ns name rest; do
  AGE=$(kubectl get challenge -n $ns $name -o jsonpath='{.metadata.creationTimestamp}')
  echo "Checking challenge: $ns/$name (created: $AGE)"

  # Check if challenge has no status (stuck)
  STATUS=$(kubectl get challenge -n $ns $name -o jsonpath='{.status.state}' 2>/dev/null || echo "empty")
  if [ "$STATUS" == "empty" ] || [ "$STATUS" == "" ]; then
    print_warning "Deleting stuck challenge: $ns/$name"
    kubectl patch challenge -n $ns $name -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl delete challenge -n $ns $name --force --grace-period=0 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 4: Trigger certificate re-issuance ==="
print_info "Refreshing certificates to create new challenges..."

# Force re-issuance by deleting and recreating certificate requests
for ns in kafka monitoring argocd dev-core prod-core; do
  kubectl get certificaterequest -n $ns --no-headers 2>/dev/null | while read name rest; do
    echo "Checking certificaterequest: $ns/$name"
    READY=$(kubectl get certificaterequest -n $ns $name -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$READY" != "True" ]; then
      print_warning "Deleting failed certificaterequest: $ns/$name"
      kubectl delete certificaterequest -n $ns $name 2>/dev/null || true
    fi
  done
done

echo ""
echo "=== Step 5: Wait for new challenges ==="
sleep 10
print_info "Current challenge status:"
kubectl get challenge -A 2>/dev/null || echo "No challenges yet"

echo ""
echo "=== Step 6: Check cert-manager logs ==="
print_info "Recent cert-manager logs:"
kubectl logs -n cert-manager -l app=cert-manager --tail=20 | grep -E "error|Error|ERROR|challenge|Challenge|ACME|acme" || echo "No errors found"

echo ""
echo "========================================"
echo "FIX COMPLETE!"
echo "========================================"
echo ""
echo "📝 Next steps:"
echo "  1. Wait 1-2 minutes for challenges to be created"
echo "  2. Check status: kubectl get certificate -A"
echo "  3. Check challenges: kubectl get challenge -A"
echo "  4. If still failing, check logs: kubectl logs -n cert-manager -l app=cert-manager --tail=50"
echo ""
echo "💡 If issues persist:"
echo "  - Verify DNS points to correct IP"
echo "  - Check Traefik is running: kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik"
echo "  - Verify ClusterIssuer: kubectl describe clusterissuer letsencrypt-prod"
echo "========================================"
