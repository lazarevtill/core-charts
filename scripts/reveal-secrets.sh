#!/bin/bash
# Reveal secrets for superusers

echo "========================================"
echo "REVEAL SECRETS (Superuser Access)"
echo "========================================"

echo ""
echo "=== ArgoCD Admin Password ==="
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo ""

echo ""
echo "=== Grafana Admin Password ==="
kubectl -n monitoring get secret grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d && echo ""

echo ""
echo "=== PostgreSQL Credentials ==="
echo "Postgres Password:"
kubectl -n database get secret postgresql -o jsonpath="{.data.postgres-password}" 2>/dev/null | base64 -d && echo ""

echo ""
echo "=== Redis Credentials ==="
echo "Redis Password:"
kubectl -n redis get secret redis -o jsonpath="{.data.redis-password}" 2>/dev/null | base64 -d && echo ""

echo ""
echo "=== All Credentials Secret ==="
kubectl -n default get secret all-credentials -o yaml 2>/dev/null | grep -A 100 "^data:" | grep -v "^data:" | while read line; do
  key=$(echo $line | cut -d: -f1 | tr -d ' ')
  value=$(echo $line | cut -d: -f2 | tr -d ' ' | base64 -d 2>/dev/null)
  if [ ! -z "$key" ]; then
    echo "$key: $value"
  fi
done

echo ""
echo "========================================" 
echo "SECURITY NOTICE: Keep these credentials private!"
echo "========================================"
