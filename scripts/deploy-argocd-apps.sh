#!/bin/bash
set -e

echo "Applying all ArgoCD applications..."
# First, apply ArgoCD projects
echo "Creating ArgoCD projects..."
kubectl apply -f argocd/projects.yaml
echo ""

for app in argocd-apps/*.yaml; do
  echo "Applying $(basename $app)..."
  kubectl apply -f "$app"
done

echo "Waiting for applications to appear in ArgoCD..."
sleep 5

echo "ArgoCD applications:"
kubectl get applications -n argocd

echo "Done! Check ArgoCD UI at https://argocd.dev.theedgestory.org"
