# Complete Authentication Setup Guide

## Overview

This guide walks you through setting up unified authentication for all services using Authentik as the single source of users.

## Current Status

✅ **ArgoCD** - Already configured with OAuth
- Client ID: `argocd`
- Client Secret: `WNrNJEj5rNh4nrwM1E5lts0gmOiCYsSKKlI2wDXB`
- Status: **READY TO TEST**

⚠️ **Grafana, Kafka UI, MinIO** - Need OAuth providers created

## Step 1: Create OAuth Providers in Authentik UI

The Authentik API has CSRF issues, so we'll create providers through the admin UI.

### Access Authentik Admin

1. Go to: https://auth.theedgestory.org/if/admin/
2. Login with:
   - Username: `akadmin`
   - Password: `Admin123!`

### Create Grafana Provider

1. Navigate to **Applications** → **Providers**
2. Click **Create**
3. Select **OAuth2/OpenID Provider**
4. Fill in:
   - **Name**: `Grafana`
   - **Authorization flow**: Default (implicit-consent)
   - **Client type**: Confidential
   - **Client ID**: `grafana`
   - **Client Secret**: *Click generate* - **SAVE THIS!**
   - **Redirect URIs**: `https://grafana.theedgestory.org/login/generic_oauth`
   - **Signing Key**: Auto-generated certificate
   - **Scopes**: openid, profile, email, ak_proxy
5. Click **Create**

6. Go to **Applications** → **Applications**
7. Click **Create**
8. Fill in:
   - **Name**: `Grafana`
   - **Slug**: `grafana`
   - **Provider**: Select the Grafana provider you just created
   - **Launch URL**: `https://grafana.theedgestory.org`
9. Click **Create**

### Create Kafka UI Provider

Repeat the same process:
- **Name**: `Kafka UI`
- **Client ID**: `kafka-ui`
- **Redirect URIs**: `https://kafka.theedgestory.org/login/oauth2/code/authentik`
- **Launch URL**: `https://kafka.theedgestory.org`

### Create MinIO Provider

Repeat the same process:
- **Name**: `MinIO`
- **Client ID**: `minio`
- **Redirect URIs**: `https://s3-admin.theedgestory.org/oauth_callback`
- **Launch URL**: `https://s3-admin.theedgestory.org`

## Step 2: Configure Services with Secrets

Once you have the client secrets, run these commands:

### Configure Grafana

```bash
GRAFANA_SECRET="<your-grafana-secret>"

kubectl create secret generic grafana-oauth -n monitoring \
  --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET="$GRAFANA_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl patch configmap grafana -n monitoring --type=merge -p="{
  \"data\": {
    \"grafana.ini\": \"[auth.generic_oauth]\\nenabled = true\\nname = Authentik\\nclient_id = grafana\\nclient_secret = $GRAFANA_SECRET\\nscopes = openid profile email groups\\nauth_url = https://auth.theedgestory.org/application/o/authorize/\\ntoken_url = https://auth.theedgestory.org/application/o/token/\\napi_url = https://auth.theedgestory.org/application/o/userinfo/\\nrole_attribute_path = contains(groups[*], 'administrators') && 'Admin' || 'Viewer'\\nallow_sign_up = true\"
  }
}"

kubectl rollout restart -n monitoring statefulset/grafana
```

### Configure Kafka UI

```bash
KAFKA_SECRET="<your-kafka-secret>"

kubectl set env deployment/kafka-ui -n infrastructure \
  AUTH_TYPE=OAUTH2 \
  OAUTH2_CLIENT_ID=kafka-ui \
  OAUTH2_CLIENT_SECRET="$KAFKA_SECRET" \
  OAUTH2_PROVIDER_ISSUER_URI=https://auth.theedgestory.org/application/o/kafka-ui \
  OAUTH2_USER_NAME_ATTRIBUTE=preferred_username \
  OAUTH2_GROUPS_CLAIM=groups \
  OAUTH2_ADMIN_GROUP=administrators
```

### Configure MinIO

```bash
MINIO_SECRET="<your-minio-secret>"

kubectl exec -n infrastructure minio-0 -- mc admin config set myminio identity_openid \
  config_url="https://auth.theedgestory.org/application/o/minio/.well-known/openid-configuration" \
  client_id="minio" \
  client_secret="$MINIO_SECRET" \
  claim_name="policy" \
  scopes="openid,profile,email,groups"

kubectl exec -n infrastructure minio-0 -- mc admin service restart myminio
```

## Step 3: Test Authentication

### Test ArgoCD (Already Configured)

1. Go to: https://argo.theedgestory.org
2. Click "Login with Authentik"
3. You should be redirected to Authentik and back
4. You should see the ArgoCD UI

### Test Grafana

1. Go to: https://grafana.theedgestory.org
2. Click "Sign in with Authentik"
3. Login and verify access

### Test Kafka UI

1. Go to: https://kafka.theedgestory.org
2. Should auto-redirect to Authentik
3. Login and verify access (admin only)

### Test MinIO

1. Go to: https://s3-admin.theedgestory.org
2. Should auto-redirect to Authentik
3. Login and verify access (admin only)

## Step 4: User Management

### Add Users to Groups

1. Go to: https://auth.theedgestory.org/if/admin/#/identity/users
2. Create or select a user
3. Go to **Groups** tab
4. Add user to either:
   - `administrators` - Full access to all services
   - `viewers` - Read-only access to Grafana

### Access Control Matrix

| Service | Administrators | Viewers | Public |
|---------|---------------|---------|--------|
| **Authentik** | ✅ Full access | ❌ Denied | ❌ Denied |
| **ArgoCD** | ✅ Full access | ❌ Denied | ❌ Denied |
| **Grafana** | ✅ Admin role | ✅ Viewer role | ❌ Denied |
| **Kafka UI** | ✅ Full access | ❌ Denied | ❌ Denied |
| **MinIO** | ✅ Full access | ❌ Denied | ❌ Denied |
| **Status Page** | ✅ Access | ✅ Access | ✅ Public |

## OIDC Endpoints Reference

For manual configuration:

- **Issuer**: `https://auth.theedgestory.org/application/o/{client_id}`
- **Authorization**: `https://auth.theedgestory.org/application/o/authorize/`
- **Token**: `https://auth.theedgestory.org/application/o/token/`
- **UserInfo**: `https://auth.theedgestory.org/application/o/userinfo/`
- **JWKS**: `https://auth.theedgestory.org/application/o/{client_id}/jwks/`
- **Logout**: `https://auth.theedgestory.org/application/o/{client_id}/end-session/`

## Troubleshooting

### CSRF Errors in Authentik API

This is a known issue. Use the UI instead of the API for creating providers.

### ArgoCD 404 on OAuth Discovery

Make sure the issuer URL has **NO trailing slash**:
- ✅ Correct: `https://auth.theedgestory.org/application/o/argocd`
- ❌ Wrong: `https://auth.theedgestory.org/application/o/argocd/`

### Service Can't Reach Authentik

Check ingress and pods:
```bash
kubectl get ingress -n authentik
kubectl get pods -n authentik
./scripts/healthcheck.sh
```

### User Can't Access Service

1. Verify user is in correct group (administrators or viewers)
2. Check policy bindings in Authentik UI
3. Check service logs for authentication errors

## Complete!

Once all providers are created and secrets configured, you'll have unified authentication across all services with Authentik as the single source of truth.
