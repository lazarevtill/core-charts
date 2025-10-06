#!/bin/bash

# Use your kubeconfig
export KUBECONFIG=~/.kube/config

echo "🔍 Kubernetes OAuth2 Investigation"
echo "===================================="

echo ""
echo "📦 All Namespaces:"
kubectl get namespaces

echo ""
echo "1️⃣ OAuth2 Proxy Namespace Resources:"
kubectl get all -n oauth2-proxy

echo ""
echo "2️⃣ OAuth2 Proxy Pod Details:"
kubectl describe pods -n oauth2-proxy -l app=oauth2-proxy | grep -A 20 "Conditions:\|Events:"

echo ""
echo "3️⃣ OAuth2 Proxy Logs (last 50 lines):"
kubectl logs -n oauth2-proxy -l app=oauth2-proxy --tail=50 --all-containers=true

echo ""
echo "4️⃣ OAuth2 Proxy Secret Keys:"
kubectl get secret oauth2-proxy -n oauth2-proxy -o jsonpath='{.data}' | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('Secret keys present:')
    for key in data.keys():
        print(f'  ✓ {key}')
except:
    print('Could not parse secret')
"

echo ""
echo "5️⃣ OAuth2 Proxy ConfigMap (Whitelist):"
kubectl get configmap oauth2-proxy-emails -n oauth2-proxy -o yaml | grep -A 20 "authenticated-emails-list.txt:"

echo ""
echo "6️⃣ OAuth2 Proxy Ingress Full YAML:"
kubectl get ingress oauth2-proxy -n oauth2-proxy -o yaml

echo ""
echo "7️⃣ All Ingresses with Auth Annotations:"
kubectl get ingress -A -o json | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('Ingresses with auth annotations:')
for item in data.get('items', []):
    name = item['metadata']['name']
    namespace = item['metadata']['namespace']
    annotations = item['metadata'].get('annotations', {})
    auth_url = annotations.get('nginx.ingress.kubernetes.io/auth-url', '')
    auth_signin = annotations.get('nginx.ingress.kubernetes.io/auth-signin', '')
    if auth_url or auth_signin:
        print(f'\n{namespace}/{name}:')
        if auth_url:
            print(f'  auth-url: {auth_url}')
        if auth_signin:
            print(f'  auth-signin: {auth_signin[:100]}...')
    else:
        print(f'{namespace}/{name}: NO AUTH')
"

echo ""
echo "8️⃣ OAuth2 Proxy Service Endpoints:"
kubectl get endpoints oauth2-proxy -n oauth2-proxy

echo ""
echo "9️⃣ nginx-ingress Controller Logs (errors only):"
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50 2>/dev/null | grep -i error || \
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 2>/dev/null | grep -i error || \
echo "Could not find ingress controller logs"

echo ""
echo "🔟 Test OAuth2 Endpoints from Inside Cluster:"
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
  sh -c "curl -I http://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180/ping" 2>/dev/null || echo "Pod test failed"

echo ""
echo "===================================="
echo "✅ Investigation Complete"
