#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
export KUBECONFIG=~/.kube/config

echo "🔍 ArgoCD Application Status Check"
echo "===================================="
echo "Using KUBECONFIG: $KUBECONFIG"
echo ""

for app in infrastructure core-pipeline-dev core-pipeline-prod landing-page; do
  echo ""
  echo "📦 Application: $app"
  echo "---"

  if kubectl get application $app -n argocd &>/dev/null; then
    # Get sync status
    SYNC_STATUS=$(kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    HEALTH_STATUS=$(kubectl get application $app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

    echo "   Sync:   $SYNC_STATUS"
    echo "   Health: $HEALTH_STATUS"

    # Get conditions (errors)
    CONDITIONS=$(kubectl get application $app -n argocd -o jsonpath='{.status.conditions}' 2>/dev/null)
    if [ -n "$CONDITIONS" ] && [ "$CONDITIONS" != "[]" ]; then
      echo "   ⚠️  Conditions:"
      kubectl get application $app -n argocd -o jsonpath='{range .status.conditions[*]}{"      - "}{.type}{": "}{.message}{"\n"}{end}' 2>/dev/null
    fi

    # Get sync operation state if exists
    OPERATION_STATE=$(kubectl get application $app -n argocd -o jsonpath='{.status.operationState.phase}' 2>/dev/null)
    if [ -n "$OPERATION_STATE" ]; then
      echo "   Operation: $OPERATION_STATE"
      OPERATION_MSG=$(kubectl get application $app -n argocd -o jsonpath='{.status.operationState.message}' 2>/dev/null)
      if [ -n "$OPERATION_MSG" ]; then
        echo "   Message: $OPERATION_MSG"
      fi
    fi

    # Get source details
    SOURCE_PATH=$(kubectl get application $app -n argocd -o jsonpath='{.spec.source.path}' 2>/dev/null)
    SOURCE_REPO=$(kubectl get application $app -n argocd -o jsonpath='{.spec.source.repoURL}' 2>/dev/null)
    echo "   Source: $SOURCE_REPO / $SOURCE_PATH"

    # Check if it's OutOfSync and get missing resources
    if [ "$SYNC_STATUS" = "OutOfSync" ]; then
      echo "   🔴 Resources Status:"
      kubectl get application $app -n argocd -o json | jq -r '.status.resources[]? | "      - \(.kind)/\(.name): \(.status // "Unknown")"' 2>/dev/null || echo "      (Could not fetch resources)"
    fi

  else
    echo "   ❌ Application not found"
  fi
done

echo ""
echo "=================================="
echo "📋 Full Application List:"
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,PATH:.spec.source.path 2>/dev/null

echo ""
echo "🔍 Detailed Infrastructure Status:"
kubectl describe application infrastructure -n argocd 2>/dev/null | tail -50
