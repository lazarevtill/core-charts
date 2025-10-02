#!/bin/bash

echo "========================================"
echo "INFRASTRUCTURE HEALTH CHECK"
echo "========================================"

echo ""
echo "=== Certificate Status ==="
kubectl get certificate -A

echo ""
echo "=== HTTP Endpoints (should redirect to HTTPS) ==="
echo "ArgoCD:"
curl -I -s http://argo.dev.theedgestory.org | head -5
echo ""
echo "Core Pipeline Dev:"
curl -I -s http://core-pipeline.dev.theedgestory.org | head -5
echo ""
echo "Core Pipeline Prod:"
curl -I -s http://core-pipeline.theedgestory.org | head -5
echo ""
echo "Kafka UI:"
curl -I -s http://kafka.dev.theedgestory.org | head -5
echo ""
echo "Grafana:"
curl -I -s http://grafana.dev.theedgestory.org | head -5
echo ""
echo "Prometheus:"
curl -I -s http://prometheus.dev.theedgestory.org | head -5

echo ""
echo "=== HTTPS Endpoints (should return 200/302) ==="
echo "ArgoCD:"
curl -I -s https://argo.dev.theedgestory.org 2>&1 | head -3
echo ""
echo "Core Pipeline Dev (Swagger):"
curl -I -s https://core-pipeline.dev.theedgestory.org/api-docs 2>&1 | head -3
echo ""
echo "Core Pipeline Prod (Swagger):"
curl -I -s https://core-pipeline.theedgestory.org/api-docs 2>&1 | head -3
echo ""
echo "Kafka UI:"
curl -I -s https://kafka.dev.theedgestory.org 2>&1 | head -3
echo ""
echo "Grafana:"
curl -I -s https://grafana.dev.theedgestory.org 2>&1 | head -3
echo ""
echo "Prometheus:"
curl -I -s https://prometheus.dev.theedgestory.org 2>&1 | head -3

echo ""
echo "=== Service Status ==="
kubectl get pods -n argocd -o wide
kubectl get pods -n dev-core -o wide
kubectl get pods -n prod-core -o wide
kubectl get pods -n kafka -o wide
kubectl get pods -n monitoring -o wide

echo ""
echo "Health check complete!"
