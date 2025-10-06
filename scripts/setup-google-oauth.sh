#!/bin/bash
set -e

echo "🔐 Google OAuth Setup for The Edge Story Infrastructure"
echo "=========================================================="
echo ""

# Check if CLIENT_ID and CLIENT_SECRET are provided
if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo "❌ Error: Required environment variables not set"
    echo ""
    echo "Please set:"
    echo "  export GOOGLE_CLIENT_ID='your-client-id'"
    echo "  export GOOGLE_CLIENT_SECRET='your-client-secret'"
    echo ""
    echo "📋 To create Google OAuth credentials:"
    echo "  1. Visit: https://console.cloud.google.com/apis/credentials"
    echo "  2. Create OAuth 2.0 Client ID (Web application)"
    echo "  3. Add authorized redirect URIs:"
    echo "     - https://grafana.theedgestory.org/login/google"
    echo "     - https://kafka.theedgestory.org/oauth2/callback"
    echo "     - https://s3-admin.theedgestory.org/oauth_callback"
    echo "     - https://dev.theedgestory.org/auth/google/callback"
    echo ""
    exit 1
fi

echo "✅ Google OAuth credentials found"
echo "   Client ID: ${GOOGLE_CLIENT_ID:0:20}..."
echo ""

# Create namespaces if they don't exist
echo "📦 Ensuring namespaces exist..."
kubectl get namespace monitoring >/dev/null 2>&1 || kubectl create namespace monitoring
kubectl get namespace infrastructure >/dev/null 2>&1 || kubectl create namespace infrastructure
kubectl get namespace minio >/dev/null 2>&1 || kubectl create namespace minio
kubectl get namespace kubero >/dev/null 2>&1 || kubectl create namespace kubero

# Create OAuth secrets in all namespaces
echo ""
echo "🔑 Creating OAuth secrets..."

for namespace in monitoring infrastructure minio kubero; do
    echo "   → $namespace"

    # Delete existing secret if it exists
    kubectl delete secret google-oauth -n $namespace --ignore-not-found=true

    # Create new secret
    kubectl create secret generic google-oauth \
        --from-literal=client-id="$GOOGLE_CLIENT_ID" \
        --from-literal=client-secret="$GOOGLE_CLIENT_SECRET" \
        -n $namespace
done

echo ""
echo "✅ OAuth secrets created in all namespaces"
echo ""
echo "📋 Next steps:"
echo "  1. Update Grafana: kubectl apply -f monitoring/deploy-grafana-oauth.yaml"
echo "  2. Update Kafka UI: kubectl apply -f monitoring/deploy-kafka-ui-oauth.yaml"
echo "  3. Update MinIO: kubectl apply -f minio/deploy-minio-oauth.yaml"
echo "  4. Update Kubero: kubectl apply -f kubero/kubero-oauth.yaml"
echo ""
echo "🎉 OAuth setup complete!"
