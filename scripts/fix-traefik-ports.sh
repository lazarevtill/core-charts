#!/bin/bash
# Fix Traefik to use standard ports 80/443 instead of 8000/8443
# Required when using Cloudflare proxy

set -e

echo "🔧 Reconfiguring Traefik to use standard ports..."
echo ""

# Update Traefik deployment to use standard ports
kubectl patch deployment traefik -n kube-system --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/args",
    "value": [
      "--entryPoints.metrics.address=:9100/tcp",
      "--entryPoints.traefik.address=:8080/tcp",
      "--entryPoints.web.address=:80/tcp",
      "--entryPoints.websecure.address=:443/tcp",
      "--entryPoints.websecure.http.tls=true",
      "--api.dashboard=true",
      "--ping=true",
      "--metrics.prometheus=true",
      "--metrics.prometheus.entrypoint=metrics",
      "--providers.kubernetescrd",
      "--log.level=INFO"
    ]
  }
]'

echo "✅ Traefik deployment updated"
echo ""

# Update Traefik service to use standard ports
kubectl patch service traefik -n kube-system --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/ports",
    "value": [
      {"name": "web", "port": 80, "targetPort": 80, "protocol": "TCP"},
      {"name": "websecure", "port": 443, "targetPort": 443, "protocol": "TCP"},
      {"name": "admin", "port": 8080, "targetPort": 8080, "protocol": "TCP"}
    ]
  }
]'

echo "✅ Traefik service updated"
echo ""
echo "⏳ Waiting for Traefik to restart..."
kubectl rollout status deployment/traefik -n kube-system --timeout=120s

echo ""
echo "✅ Traefik now uses standard ports 80/443"
echo ""
echo "Test the landing page:"
echo "  curl -I https://theedgestory.org"
