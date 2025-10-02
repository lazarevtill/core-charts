#!/bin/bash
# Sync current repository state to Gitea from inside the cluster
# This script creates a temporary pod to push to Gitea since cluster DNS isn't accessible from host

REPO_PATH=${1:-/root/core-charts}

echo "Syncing repository to Gitea for ArgoCD visualization..."

# Get current commit hash
cd "$REPO_PATH"
COMMIT_HASH=$(git rev-parse HEAD)

# Create a temporary pod to push to Gitea
kubectl run gitea-sync-$COMMIT_HASH --rm -i --restart=Never --image=alpine/git:latest -- sh -c "
  set -e
  cd /tmp
  git clone --depth 1 https://github.com/uz0/core-charts.git
  cd core-charts
  git remote add gitea http://argocd:argocd-password@gitea.argocd.svc.cluster.local:3000/argocd/core-charts.git
  git push gitea main --force
  echo '✅ Synced to Gitea'
" 2>&1 || echo "⚠️  Gitea sync failed (may not be initialized yet)"

echo "Gitea sync triggered"
