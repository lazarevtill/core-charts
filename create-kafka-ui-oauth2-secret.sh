#!/bin/bash
set -e

# Script to create Kafka UI OAuth2 secret on Kubernetes cluster
# This secret contains Google OAuth2 credentials and should NEVER be committed to Git

echo "🔐 Creating Kafka UI OAuth2 Secret"
echo "=================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

# OAuth2 credentials - read from OAuth2 Proxy existing secret
echo "Extracting Google OAuth2 credentials from oauth2-proxy secret..."
GOOGLE_CLIENT_ID=$(kubectl get secret oauth2-proxy -n oauth2-proxy -o jsonpath='{.data.client-id}' | base64 -d)
GOOGLE_CLIENT_SECRET=$(kubectl get secret oauth2-proxy -n oauth2-proxy -o jsonpath='{.data.client-secret}' | base64 -d)

if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo "❌ ERROR: Could not extract OAuth2 credentials from oauth2-proxy secret"
    echo "   Make sure oauth2-proxy secret exists in oauth2-proxy namespace"
    exit 1
fi

echo "✅ Successfully extracted OAuth2 credentials"

echo "1️⃣  Creating namespace 'infrastructure' if it doesn't exist..."
kubectl create namespace infrastructure --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "2️⃣  Deleting old secret if it exists..."
kubectl delete secret kafka-ui-oauth2-secret -n infrastructure 2>/dev/null || echo "   No old secret found"

echo ""
echo "3️⃣  Creating new OAuth2 secret..."
kubectl create secret generic kafka-ui-oauth2-secret \
  -n infrastructure \
  --from-literal=AUTH_OAUTH2_CLIENT_GOOGLE_CLIENTID="$GOOGLE_CLIENT_ID" \
  --from-literal=AUTH_OAUTH2_CLIENT_GOOGLE_CLIENTSECRET="$GOOGLE_CLIENT_SECRET"

echo ""
echo "4️⃣  Verifying secret creation..."
kubectl get secret kafka-ui-oauth2-secret -n infrastructure

echo ""
echo "✅ SUCCESS! OAuth2 secret created"
echo ""
echo "Next steps:"
echo "  1. Commit and push the Helm chart changes (secrets are NOT in Git)"
echo "  2. ArgoCD will auto-sync and deploy Kafka UI"
echo "  3. Kafka UI will use the secret for Google OAuth2 authentication"
echo ""
echo "Security:"
echo "  - Secret is only in Kubernetes, never committed to Git"
echo "  - Only dcversus@gmail.com can authenticate"
echo "  - All other users will receive 'Access Denied' errors"
