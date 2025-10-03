#!/bin/bash
# Comprehensive GitHub connectivity testing from cluster

echo "========================================"
echo "GitHub Connectivity Diagnostic Tests"
echo "========================================"
echo ""

echo "=== Test 1: Basic DNS Resolution ==="
kubectl run dns-test --rm -i --restart=Never --image=busybox:latest -- \
  nslookup github.com
echo ""

echo "=== Test 2: HTTPS Connectivity to GitHub ==="
kubectl run https-test --rm -i --restart=Never --image=curlimages/curl:latest -- \
  curl -I https://github.com 2>&1
echo ""

echo "=== Test 3: Access Specific Repository (Web) ==="
kubectl run repo-web-test --rm -i --restart=Never --image=curlimages/curl:latest -- \
  curl -I https://github.com/uz0/core-charts 2>&1
echo ""

echo "=== Test 4: Git Protocol Access ==="
kubectl run git-ls-test --rm -i --restart=Never --image=alpine/git:latest -- \
  git ls-remote https://github.com/uz0/core-charts.git HEAD 2>&1
echo ""

echo "=== Test 5: Clone Repository (Small) ==="
kubectl run git-clone-test --rm -i --restart=Never --image=alpine/git:latest -- \
  sh -c 'git clone --depth 1 https://github.com/uz0/core-charts.git /tmp/test && ls -la /tmp/test' 2>&1
echo ""

echo "=== Test 6: ArgoCD Repo Server Logs ==="
echo "Recent ArgoCD repo-server logs:"
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=50 | grep -i "github\|error\|failed" || echo "No errors found"
echo ""

echo "=== Test 7: Check ArgoCD Application Source ==="
for app in infrastructure core-pipeline-dev core-pipeline-prod; do
  echo "--- $app source configuration ---"
  kubectl get application $app -n argocd -o jsonpath='{.spec.source}' | jq . 2>/dev/null || \
    kubectl get application $app -n argocd -o jsonpath='{.spec.source}'
  echo ""
done
echo ""

echo "=== Test 8: Validate Chart Paths Exist in Repo ==="
echo "Checking if chart paths are valid..."
kubectl run chart-check --rm -i --restart=Never --image=alpine/git:latest -- \
  sh -c 'git clone --depth 1 https://github.com/uz0/core-charts.git /tmp/repo && \
         ls -la /tmp/repo/charts/ && \
         echo "=== Infrastructure chart ===" && ls -la /tmp/repo/charts/infrastructure/ && \
         echo "=== Core-pipeline chart ===" && ls -la /tmp/repo/charts/core-pipeline/' 2>&1
echo ""

echo "=== Test 9: ArgoCD Server Connectivity Test ==="
echo "Testing if ArgoCD can reach GitHub API..."
kubectl exec -n argocd deployment/argocd-repo-server -- \
  sh -c 'wget -O- --timeout=5 https://api.github.com/repos/uz0/core-charts 2>&1 | head -20' || \
  echo "ArgoCD repo-server cannot reach GitHub"
echo ""

echo "========================================"
echo "Tests Complete"
echo "========================================"
