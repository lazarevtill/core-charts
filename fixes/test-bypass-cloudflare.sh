#!/bin/bash

# Test script to verify services work when bypassing Cloudflare
# Run this on the server or from a machine where you can modify /etc/hosts

echo "Testing services by bypassing Cloudflare..."
echo ""
echo "Method 1: Using curl with Host header (from server)"
echo "=================================================="

# Test Authentik
echo "Testing Authentik..."
kubectl run test-bypass --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -I http://authentik-server.authentik.svc.cluster.local 2>/dev/null | grep -E "^HTTP|^Location"

# Test ArgoCD
echo ""
echo "Testing ArgoCD..."
kubectl run test-bypass --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -I http://argocd-server.argocd.svc.cluster.local 2>/dev/null | grep -E "^HTTP|^Location"

# Test Kafka UI
echo ""
echo "Testing Kafka UI..."
kubectl run test-bypass --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -I http://kafka-ui.infrastructure.svc.cluster.local:8080 2>/dev/null | grep -E "^HTTP|^Location"

echo ""
echo "Method 2: Direct IP test with Host header"
echo "=========================================="
echo "Run these commands to test:"
echo ""
echo "# Test Authentik"
echo 'curl -k -H "Host: auth.theedgestory.org" https://46.62.223.198'
echo ""
echo "# Test ArgoCD"
echo 'curl -k -H "Host: argo.theedgestory.org" https://46.62.223.198'
echo ""
echo "# Test Kafka UI"
echo 'curl -k -H "Host: kafka.theedgestory.org" https://46.62.223.198'

echo ""
echo "Method 3: Modify /etc/hosts (on your local machine)"
echo "===================================================="
echo "Add these lines to /etc/hosts:"
echo ""
echo "46.62.223.198 auth.theedgestory.org"
echo "46.62.223.198 argo.theedgestory.org"
echo "46.62.223.198 kafka.theedgestory.org"
echo ""
echo "Then open in browser:"
echo "- https://auth.theedgestory.org"
echo "- https://argo.theedgestory.org"
echo "- https://kafka.theedgestory.org"

echo ""
echo "Expected Results:"
echo "================="
echo "- Authentik: Should show login page or redirect to /flows/default/authentication/"
echo "- ArgoCD: Should show login page"
echo "- Kafka UI: Should show login or main interface"
echo ""
echo "If these work when bypassing Cloudflare, the issue is confirmed to be Cloudflare configuration."