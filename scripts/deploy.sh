#!/bin/bash
# Deployment Script
# Updates existing infrastructure and applications via ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

APP_NAME=${1:-"all"}

echo "=== Deploying via ArgoCD ==="
echo ""

# Check if ArgoCD is available
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "${RED}ArgoCD namespace not found. Please run ./scripts/setup.sh first${NC}"
    exit 1
fi

# Sync ArgoCD applications
sync_app() {
    local app=$1
    echo "Syncing $app..."

    kubectl patch application $app -n argocd \
        --type merge \
        -p '{"operation":{"sync":{"revision":"HEAD"}}}' \
        >/dev/null 2>&1

    echo -e "${GREEN}✓ $app sync triggered${NC}"
}

# Wait for sync
wait_for_sync() {
    local app=$1
    echo "Waiting for $app to sync..."

    timeout 120s bash -c "until kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}' | grep -q 'Synced'; do sleep 2; done" \
        && echo -e "${GREEN}✓ $app synced${NC}" \
        || echo -e "${YELLOW}⚠ $app sync timeout (check ArgoCD UI)${NC}"
}

# Deploy specific app or all
if [ "$APP_NAME" == "all" ]; then
    echo "Deploying all applications..."
    echo ""

    # Infrastructure first (sync-wave 0-1)
    sync_app "infrastructure"
    wait_for_sync "infrastructure"

    # OAuth2 Proxy
    sync_app "oauth2-proxy"
    wait_for_sync "oauth2-proxy"

    # Applications (sync-wave 2)
    sync_app "core-pipeline-dev"
    sync_app "core-pipeline-prod"

    echo ""
    echo -e "${GREEN}All applications deployed${NC}"

elif kubectl get application $APP_NAME -n argocd >/dev/null 2>&1; then
    sync_app "$APP_NAME"
    wait_for_sync "$APP_NAME"

else
    echo -e "${RED}Application $APP_NAME not found${NC}"
    echo ""
    echo "Available applications:"
    kubectl get applications -n argocd -o name | sed 's|application.argoproj.io/||'
    exit 1
fi

echo ""
echo "Check status: kubectl get applications -n argocd"
echo "View logs: kubectl logs -n <namespace> <pod-name>"
echo "ArgoCD UI: https://argo.theedgestory.org"
