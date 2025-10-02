#!/bin/bash
# Initialize Gitea with core-charts repository for ArgoCD visualization
# This script runs a Kubernetes Job that handles the initialization from inside the cluster

set -e

echo "=== Initializing Local Git Server (Gitea) for ArgoCD ==="

# Apply the initialization job
echo "Creating Gitea initialization job..."
kubectl apply -f /root/core-charts/argocd/init-gitea-job.yaml

# Wait for job to complete
echo "Waiting for initialization to complete..."
kubectl wait --for=condition=complete job/gitea-init -n argocd --timeout=600s

# Show job logs
echo ""
echo "=== Initialization Logs ==="
kubectl logs job/gitea-init -n argocd

echo ""
echo "✅ Gitea initialization complete!"
echo "Repository URL: http://gitea.argocd.svc.cluster.local:3000/argocd/core-charts.git"
echo ""
echo "To update the repository manually from inside the cluster:"
echo "  kubectl run git-push --rm -it --image=alpine/git --restart=Never -- sh -c 'git clone https://github.com/uz0/core-charts.git /tmp/repo && cd /tmp/repo && git remote add gitea http://argocd:argocd-password@gitea.argocd.svc.cluster.local:3000/argocd/core-charts.git && git push gitea main --force'"
