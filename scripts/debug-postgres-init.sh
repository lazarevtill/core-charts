#!/bin/bash
# Debug script for PostgreSQL init job issues

echo "=== Checking PostgreSQL Pod Status ==="
kubectl get pods -n infrastructure -l app.kubernetes.io/name=postgresql

echo -e "\n=== Checking PostgreSQL Service ==="
kubectl get svc -n infrastructure | grep postgresql

echo -e "\n=== Checking DB Init Job ==="
kubectl get jobs -n infrastructure | grep db-init

echo -e "\n=== DB Init Job Logs (last 30 lines) ==="
POD=$(kubectl get pods -n infrastructure -l app=postgresql-init --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
  kubectl logs -n infrastructure $POD --tail=30
else
  echo "No running db-init pod found"
fi

echo -e "\n=== PostgreSQL Pod Logs (last 20 lines) ==="
PG_POD=$(kubectl get pods -n infrastructure -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$PG_POD" ]; then
  kubectl logs -n infrastructure $PG_POD --tail=20
else
  echo "No PostgreSQL pod found"
fi

echo -e "\n=== Test DNS Resolution from db-init pod ==="
if [ -n "$POD" ]; then
  kubectl exec -n infrastructure $POD -- nslookup infrastructure-postgresql.infrastructure.svc.cluster.local 2>&1 || echo "DNS test failed"
fi

echo -e "\n=== Test PostgreSQL Connection ==="
if [ -n "$POD" ]; then
  PGPASS=$(kubectl get secret -n infrastructure infrastructure-postgresql -o jsonpath='{.data.postgres-password}' | base64 -d)
  kubectl exec -n infrastructure $POD -- env PGPASSWORD="$PGPASS" psql -h infrastructure-postgresql.infrastructure.svc.cluster.local -U postgres -c '\l' 2>&1 || echo "Connection test failed"
fi
