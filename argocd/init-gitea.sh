#!/bin/bash
# Initialize Gitea with core-charts repository for ArgoCD

set -e

echo "=== Initializing Local Git Server (Gitea) for ArgoCD ==="

# Deploy Gitea
echo "Deploying Gitea..."
kubectl apply -f /root/core-charts/argocd/gitea.yaml

# Wait for Gitea to be ready
echo "Waiting for Gitea to be ready..."
kubectl wait --for=condition=ready pod -l app=gitea -n argocd --timeout=300s

# Create admin user and repository via Gitea CLI
echo "Creating admin user and repository..."
kubectl exec -n argocd deployment/gitea -- gitea admin user create \
  --username argocd \
  --password argocd-password \
  --email argocd@local \
  --admin || echo "User may already exist"

# Create repository
kubectl exec -n argocd deployment/gitea -- gitea admin repo create \
  --owner argocd \
  --name core-charts \
  --private=false || echo "Repository may already exist"

# Clone and push to Gitea
echo "Pushing repository to Gitea..."
cd /root/core-charts

# Add Gitea as remote
git remote remove gitea 2>/dev/null || true
git remote add gitea http://argocd:argocd-password@gitea.argocd.svc.cluster.local:3000/argocd/core-charts.git

# Push to Gitea
git push gitea main --force

echo "✅ Gitea initialized successfully"
echo "Repository URL: http://gitea.argocd.svc.cluster.local:3000/argocd/core-charts.git"
