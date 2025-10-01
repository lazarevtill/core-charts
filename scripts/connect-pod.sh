#!/bin/bash
# Connect to a pod with kubectl exec

if [ -z "$1" ]; then
  echo "Usage: $0 <pod-name-pattern> [namespace]"
  echo ""
  echo "Examples:"
  echo "  $0 core-pipeline-dev"
  echo "  $0 grafana monitoring"
  echo "  $0 argocd argocd"
  exit 1
fi

PATTERN=$1
NAMESPACE=${2:-""}

if [ -z "$NAMESPACE" ]; then
  echo "Searching for pods matching '$PATTERN' in all namespaces..."
  POD=$(kubectl get pods -A | grep "$PATTERN" | grep Running | head -1 | awk '{print $1 " " $2}')
  
  if [ -z "$POD" ]; then
    echo "No running pods found matching '$PATTERN'"
    exit 1
  fi
  
  NS=$(echo $POD | awk '{print $1}')
  NAME=$(echo $POD | awk '{print $2}')
else
  echo "Searching for pods matching '$PATTERN' in namespace '$NAMESPACE'..."
  NAME=$(kubectl get pods -n $NAMESPACE | grep "$PATTERN" | grep Running | head -1 | awk '{print $1}')
  
  if [ -z "$NAME" ]; then
    echo "No running pods found matching '$PATTERN' in namespace '$NAMESPACE'"
    exit 1
  fi
  
  NS=$NAMESPACE
fi

echo "Connecting to pod: $NAME in namespace: $NS"
kubectl exec -it -n $NS $NAME -- /bin/sh || kubectl exec -it -n $NS $NAME -- /bin/bash
