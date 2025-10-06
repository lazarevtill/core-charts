#!/bin/bash
set -e

echo "🧹 Cleaning up ArgoCD applications..."

# Delete landing page application (migrated to GitHub Pages)
echo "Deleting landing page application..."
kubectl delete application landing-page -n argocd --ignore-not-found=true

# Delete old infrastructure resources that aren't managed by Helm
echo "Cleaning old infrastructure resources..."
kubectl delete -f k8s/infrastructure/ --ignore-not-found=true 2>/dev/null || true

# Apply updated ArgoCD applications
echo "Applying updated ArgoCD applications..."
kubectl apply -f argocd-apps/

# Trigger sync for all applications
echo "Triggering ArgoCD sync..."
kubectl patch application infrastructure -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}' || true
kubectl patch application core-pipeline-dev -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}' || true
kubectl patch application core-pipeline-prod -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}' || true

echo "✅ Done! Check ArgoCD UI: https://argo.dev.theedgestory.org"
