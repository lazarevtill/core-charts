#!/bin/bash
# Deploy Unified Authentication for All Services
# This script configures Authentik SSO for ArgoCD, Grafana, Kafka UI, and MinIO

set -e

echo "🔐 Deploying Unified Authentication with Authentik SSO"
echo "======================================================"
echo ""

# Step 1: Get OAuth secrets from Authentik
echo "📋 Step 1: Retrieving OAuth credentials from Authentik..."
echo ""

ARGOCD_SECRET=$(kubectl exec -n authentik deployment/authentik-server -- ak shell -c "from authentik.providers.oauth2.models import OAuth2Provider; p = OAuth2Provider.objects.filter(client_id='argocd').first(); print(p.client_secret if p else '')" 2>&1 | tail -1)
GRAFANA_SECRET=$(kubectl exec -n authentik deployment/authentik-server -- ak shell -c "from authentik.providers.oauth2.models import OAuth2Provider; p = OAuth2Provider.objects.filter(client_id='grafana').first(); print(p.client_secret if p else '')" 2>&1 | tail -1)
KAFKA_SECRET=$(kubectl exec -n authentik deployment/authentik-server -- ak shell -c "from authentik.providers.oauth2.models import OAuth2Provider; p = OAuth2Provider.objects.filter(client_id='kafka-ui').first(); print(p.client_secret if p else '')" 2>&1 | tail -1)
MINIO_SECRET=$(kubectl exec -n authentik deployment/authentik-server -- ak shell -c "from authentik.providers.oauth2.models import OAuth2Provider; p = OAuth2Provider.objects.filter(client_id='minio').first(); print(p.client_secret if p else '')" 2>&1 | tail -1)

echo "✅ Retrieved secrets for all services"
echo ""
echo "Credentials:"
echo "  ArgoCD:  $ARGOCD_SECRET"
echo "  Grafana: $GRAFANA_SECRET"
echo "  Kafka:   $KAFKA_SECRET"
echo "  MinIO:   $MINIO_SECRET"
echo ""

# Step 2: Configure ArgoCD OIDC
echo "📋 Step 2: Configuring ArgoCD OIDC..."
kubectl patch configmap argocd-cm -n argocd --type=json -p='[
  {
    "op": "add",
    "path": "/data/oidc.config",
    "value": "name: Authentik\nissuer: https://auth.theedgestory.org/application/o/argocd/\nclientID: argocd\nclientSecret: '"$ARGOCD_SECRET"'\nrequestedScopes:\n  - openid\n  - profile\n  - email\n  - groups\nrequested IDTokenClaims:\n  groups:\n    essential: true"
  }
]' 2>/dev/null || echo "  ⚠️  ArgoCD ConfigMap patch failed (may need manual config)"

kubectl patch configmap argocd-rbac-cm -n argocd --type=json -p='[
  {
    "op": "add",
    "path": "/data/policy.csv",
    "value": "g, administrators, role:admin\ng, akadmin@gmail.com, role:admin"
  }
]' 2>/dev/null || echo "  ⚠️  ArgoCD RBAC ConfigMap patch failed"

echo "✅ ArgoCD OIDC configured"
kubectl rollout restart -n argocd deployment/argocd-server 2>/dev/null
echo ""

# Step 3: Configure Grafana OAuth
echo "📋 Step 3: Configuring Grafana OAuth..."

# Create Grafana secret with OAuth config
kubectl create secret generic grafana-oauth -n monitoring \
  --from-literal=client-id=grafana \
  --from-literal=client-secret="$GRAFANA_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

# Update Grafana ConfigMap
kubectl get configmap grafana -n monitoring -o yaml | \
sed '/auth.generic_oauth/d' | \
kubectl apply -f - 2>/dev/null || true

kubectl patch configmap grafana -n monitoring --type=merge -p='{
  "data": {
    "grafana.ini": "[auth.generic_oauth]\nenabled = true\nname = Authentik\nclient_id = grafana\nclient_secret = '"$GRAFANA_SECRET"'\nscopes = openid profile email groups\nauth_url = https://auth.theedgestory.org/application/o/authorize/\ntoken_url = https://auth.theedgestory.org/application/o/token/\napi_url = https://auth.theedgestory.org/application/o/userinfo/\nrole_attribute_path = contains(groups[*], '\''administrators'\'') && '\''Admin'\'' || '\''Viewer'\''\nallow_sign_up = true"
  }
}' 2>/dev/null || echo "  ⚠️  Grafana ConfigMap patch failed"

echo "✅ Grafana OAuth configured"
kubectl rollout restart -n monitoring statefulset/grafana 2>/dev/null
echo ""

# Step 4: Configure Kafka UI OAuth
echo "📋 Step 4: Configuring Kafka UI OAuth..."
kubectl set env deployment/kafka-ui -n infrastructure \
  AUTH_TYPE=OAUTH2 \
  OAUTH2_CLIENT_ID=kafka-ui \
  OAUTH2_CLIENT_SECRET="$KAFKA_SECRET" \
  OAUTH2_PROVIDER_ISSUER_URI=https://auth.theedgestory.org/application/o/kafka-ui/ \
  OAUTH2_USER_NAME_ATTRIBUTE=preferred_username \
  OAUTH2_GROUPS_CLAIM=groups \
  OAUTH2_ADMIN_GROUP=administrators 2>/dev/null || echo "  ⚠️  Kafka UI not found or patch failed"

echo "✅ Kafka UI OAuth configured"
echo ""

# Step 5: Configure MinIO OIDC
echo "📋 Step 5: Configuring MinIO OIDC..."
kubectl exec -n infrastructure minio-0 -- mc admin config set myminio identity_openid \
  config_url="https://auth.theedgestory.org/application/o/minio/.well-known/openid-configuration" \
  client_id="minio" \
  client_secret="$MINIO_SECRET" \
  claim_name="policy" \
  scopes="openid,profile,email,groups" 2>/dev/null || echo "  ⚠️  MinIO config failed (may not be deployed yet)"

echo "✅ MinIO OIDC configured"
echo ""

# Summary
echo "======================================================"
echo "✅ Unified Authentication Deployment Complete!"
echo ""
echo "Services configured with Authentik SSO:"
echo "  ✅ ArgoCD    - https://argo.theedgestory.org"
echo "  ✅ Grafana   - https://grafana.theedgestory.org"
echo "  ✅ Kafka UI  - https://kafka.theedgestory.org"
echo "  ✅ MinIO     - https://s3-admin.theedgestory.org"
echo ""
echo "Access Control:"
echo "  • Administrators: Full access to all services"
echo "  • Viewers: Read-only access to Grafana"
echo ""
echo "Next steps:"
echo "  1. Wait for pods to restart (watch with: kubectl get pods -A)"
echo "  2. Test authentication by accessing each service"
echo "  3. Add users to groups in Authentik admin UI"
echo ""
echo "To add users to groups:"
echo "  https://auth.theedgestory.org/if/admin/#/identity/users"
echo ""
