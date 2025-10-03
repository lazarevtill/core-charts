#!/bin/bash
# Comprehensive ArgoCD and GitOps investigation script

echo "=========================================="
echo "ArgoCD & GitOps Architecture Investigation"
echo "=========================================="
echo ""

echo "=== 1. Current ArgoCD Status ==="
echo ""
echo "ArgoCD Applications:"
kubectl get applications -n argocd -o wide
echo ""

echo "ArgoCD Application Details:"
for app in infrastructure core-pipeline-dev core-pipeline-prod; do
  echo "--- $app ---"
  kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null && echo " (Sync Status)"
  kubectl get application $app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null && echo " (Health Status)"
  kubectl get application $app -n argocd -o jsonpath='{.status.conditions[*].message}' 2>/dev/null && echo ""
  echo ""
done

echo "=== 2. GitHub Connectivity Test ==="
echo ""
echo "Testing GitHub access from cluster..."
kubectl run github-test --rm -it --restart=Never --image=alpine/git -- \
  sh -c "timeout 10 git ls-remote https://github.com/uz0/core-charts.git HEAD 2>&1" || \
  echo "FAILED: Cannot connect to GitHub from cluster"
echo ""

echo "=== 3. Current Gitea Status ==="
echo ""
echo "Gitea Pod:"
kubectl get pods -n argocd -l app=gitea
echo ""
echo "Gitea Service:"
kubectl get svc -n argocd gitea
echo ""

echo "Testing Gitea connectivity from cluster..."
kubectl run gitea-test --rm -it --restart=Never --image=alpine/git -- \
  sh -c "git ls-remote http://argocd:argocd-password@gitea.argocd.svc.cluster.local:3000/argocd/core-charts.git HEAD 2>&1" || \
  echo "FAILED: Cannot access Gitea repository"
echo ""

echo "=== 4. Actual Deployed Resources ==="
echo ""
echo "Infrastructure namespace:"
kubectl get pods,svc -n infrastructure
echo ""
echo "Dev namespace:"
kubectl get pods,svc -n dev-core
echo ""
echo "Prod namespace:"
kubectl get pods,svc -n prod-core
echo ""

echo "=== 5. Webhook System Status ==="
echo ""
echo "Webhook receiver service:"
systemctl status webhook-receiver --no-pager | head -20
echo ""

echo "=== 6. ArgoCD Repository Configuration ==="
echo ""
kubectl get secret -n argocd -l "argocd.argoproj.io/secret-type=repository"
echo ""

echo "=== 7. ArgoCD Projects ==="
echo ""
kubectl get appproject -n argocd
echo ""

echo "=========================================="
echo "Investigation Complete"
echo "=========================================="
