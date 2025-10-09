#!/bin/bash
# Deploy Script - Applies changes from core-charts repository via ArgoCD

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Deploying Core Charts Updates ===${NC}"

# Sync with git
echo -e "${YELLOW}Pulling latest changes...${NC}"
git pull origin main

# Apply ArgoCD applications
echo -e "${YELLOW}Updating ArgoCD applications...${NC}"
kubectl apply -f argocd-apps/

# Trigger sync for all applications
echo -e "${YELLOW}Syncing applications...${NC}"
for app in $(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}'); do
    echo "  Syncing: $app"
    kubectl patch application $app -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}' || true
done

# Wait for sync
echo -e "${YELLOW}Waiting for sync to complete...${NC}"
sleep 10

# Check status
echo -e "${GREEN}Application Status:${NC}"
kubectl get applications -n argocd

echo -e "${GREEN}Deploy complete!${NC}"