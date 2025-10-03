#!/bin/bash
# Push repository to Gitea using port-forward
set -e

REPO_DIR=${1:-/root/core-charts}

echo "=== Pushing repository to Gitea via port-forward ==="

cd "$REPO_DIR"

# Start port-forward in background
echo "Starting port-forward to Gitea..."
kubectl port-forward -n argocd svc/gitea 3000:3000 >/dev/null 2>&1 &
PF_PID=$!

# Wait for port-forward to be ready
sleep 3

# Trap to cleanup port-forward on exit
trap "kill $PF_PID 2>/dev/null || true" EXIT

# Add Gitea remote (remove if exists)
echo "Configuring git remote..."
git remote remove gitea-local 2>/dev/null || true
git remote add gitea-local http://argocd:argocd-password@localhost:3000/argocd/core-charts.git

# Push to Gitea
echo "Pushing to Gitea..."
git push gitea-local main --force

echo "✅ Repository pushed to Gitea successfully"
echo "Repository URL (cluster-internal): http://gitea.argocd.svc.cluster.local:3000/argocd/core-charts.git"

# Cleanup happens via trap
