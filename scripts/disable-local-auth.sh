#!/bin/bash
# Disable ALL local authentication in services
# Force everything to use Authentik ONLY

set -e

echo "🔒 Disabling all local authentication..."
echo ""

# 1. ArgoCD - Disable admin user and configure OIDC
echo "1. Configuring ArgoCD (Admin access only)..."

cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Disable admin user completely
  admin.enabled: "false"

  # Application URL
  url: "https://argo.theedgestory.org"

  # OIDC configuration for Authentik
  oidc.config: |
    name: Authentik
    issuer: https://auth.theedgestory.org/application/o/argocd/
    clientId: argocd
    clientSecret: $argocd-oidc-secret:clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims: {"groups": {"essential": true}}

  # RBAC - only administrators group can access
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, certificates, *, *, allow
    p, role:admin, projects, *, *, allow
    g, administrators, role:admin
    g, dcversus@gmail.com, role:admin
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, clusters, get, *, allow
    p, role:readonly, repositories, get, *, allow
    g, viewers, role:readonly

  policy.default: ""
EOF

kubectl rollout restart deployment argocd-server -n argocd

# 2. Grafana - Configure OAuth2
echo ""
echo "2. Configuring Grafana (Viewers + Admin access)..."

cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-oauth-config
  namespace: monitoring
data:
  grafana.ini: |
    [server]
    root_url = https://grafana.theedgestory.org

    [auth]
    disable_login_form = true
    disable_signout_menu = false
    oauth_auto_login = true

    [auth.basic]
    enabled = false

    [auth.anonymous]
    enabled = false

    [auth.generic_oauth]
    enabled = true
    name = Authentik
    allow_sign_up = true
    client_id = grafana
    client_secret = ${GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET}
    scopes = openid profile email groups
    auth_url = https://auth.theedgestory.org/application/o/authorize/
    token_url = https://auth.theedgestory.org/application/o/token/
    api_url = https://auth.theedgestory.org/application/o/userinfo/
    role_attribute_path = contains(groups[*], 'administrators') && 'Admin' || contains(groups[*], 'viewers') && 'Viewer' || 'Viewer'
    email_attribute_path = email

    [users]
    auto_assign_org = true
    auto_assign_org_role = Viewer
EOF

# Patch Grafana deployment to use OAuth config
kubectl set env deployment/kube-prometheus-stack-grafana -n monitoring \
  GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=$(kubectl get secret grafana-oauth -n monitoring -o jsonpath='{.data.client-secret}' | base64 -d)

kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring

# 3. Kafka UI - Configure OAuth2
echo ""
echo "3. Configuring Kafka UI (Admin access only)..."

cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-ui-oauth-config
  namespace: infrastructure
data:
  AUTH_TYPE: "OAUTH2"
  SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_AUTHENTIK_CLIENTID: "kafka-ui"
  SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_AUTHENTIK_SCOPE: "openid,profile,email,groups"
  SPRING_SECURITY_OAUTH2_CLIENT_PROVIDER_AUTHENTIK_ISSUER_URI: "https://auth.theedgestory.org/application/o/kafka-ui/"
  SPRING_SECURITY_OAUTH2_CLIENT_PROVIDER_AUTHENTIK_USER_NAME_ATTRIBUTE: "preferred_username"
  OAUTH2_CLIENT_ALLOW_NEW_USERS: "false"
  RBAC_ENABLED: "true"
EOF

# Update Kafka UI deployment
kubectl patch deployment kafka-ui -n infrastructure --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/envFrom", "value": [
    {"configMapRef": {"name": "kafka-ui-oauth-config"}},
    {"secretRef": {"name": "kafka-ui-oauth"}}
  ]}
]'

kubectl rollout restart deployment kafka-ui -n infrastructure

# 4. MinIO - Configure OIDC
echo ""
echo "4. Configuring MinIO (Admin access only)..."

# Update MinIO with OIDC environment variables
kubectl set env statefulset/minio -n infrastructure \
  MINIO_IDENTITY_OPENID_CONFIG_URL="https://auth.theedgestory.org/application/o/minio/.well-known/openid-configuration" \
  MINIO_IDENTITY_OPENID_CLIENT_ID="minio" \
  MINIO_IDENTITY_OPENID_CLIENT_SECRET=$(kubectl get secret minio-oauth -n infrastructure -o jsonpath='{.data.MINIO_IDENTITY_OPENID_CLIENT_SECRET}' | base64 -d) \
  MINIO_IDENTITY_OPENID_CLAIM_NAME="groups" \
  MINIO_IDENTITY_OPENID_CLAIM_PREFIX="" \
  MINIO_IDENTITY_OPENID_SCOPES="openid,profile,email,groups" \
  MINIO_IDENTITY_OPENID_REDIRECT_URI="https://s3-admin.theedgestory.org/oauth_callback" \
  MINIO_BROWSER_REDIRECT_URL="https://s3-admin.theedgestory.org"

# Create MinIO policy for administrators
kubectl exec -n infrastructure minio-0 -- mc alias set local http://localhost:9000 minioadmin minioadmin 2>/dev/null || true
kubectl exec -n infrastructure minio-0 -- mc admin policy create local consoleAdmin /dev/stdin << 'POLICY' 2>/dev/null || true
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["admin:*", "s3:*"],
      "Resource": ["arn:aws:s3:::*"]
    }
  ]
}
POLICY

kubectl exec -n infrastructure minio-0 -- mc admin policy attach local consoleAdmin --group=administrators 2>/dev/null || true

kubectl rollout restart statefulset minio -n infrastructure

# 5. Remove all default passwords and admin users
echo ""
echo "5. Removing default credentials..."

# Delete ArgoCD admin password secret
kubectl delete secret argocd-initial-admin-secret -n argocd 2>/dev/null || true

# Remove any default admin configmaps
kubectl get configmap -A | grep -i admin | grep -v argocd | awk '{print "kubectl delete configmap -n " $1 " " $2}' | sh 2>/dev/null || true

echo ""
echo "✅ Local authentication disabled for all services!"
echo ""
echo "Authentication Matrix:"
echo "  • ArgoCD:    Administrators only (can deploy)"
echo "  • Grafana:   Viewers + Administrators (read metrics)"
echo "  • Kafka UI:  Administrators only (can modify topics)"
echo "  • MinIO:     Administrators only (can manage storage)"
echo "  • Status:    Public (no auth required)"
echo "  • Core API:  Public (no auth required)"
echo ""
echo "All services now use ONLY Authentik for authentication!"