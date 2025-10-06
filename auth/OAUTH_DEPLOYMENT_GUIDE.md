# Google OAuth Unified Authentication - Deployment Guide

## Overview

This guide sets up unified Google OAuth authentication for all infrastructure services:
- 📊 **Grafana** - https://grafana.theedgestory.org
- 📨 **Kafka UI** - https://kafka.theedgestory.org
- 💾 **MinIO S3 Admin** - https://s3-admin.theedgestory.org
- 🔧 **Kubero PaaS** - https://dev.theedgestory.org

## Prerequisites

1. Google Cloud Project with OAuth 2.0 configured
2. kubectl access to the cluster
3. Cluster must have these namespaces: `monitoring`, `minio`, `kubero`

## Step 1: Create Google OAuth Credentials

### 1.1 Create OAuth Client

1. Visit https://console.cloud.google.com/apis/credentials
2. Create project: "The Edge Story Infrastructure" (or use existing)
3. Click "Create Credentials" → "OAuth 2.0 Client ID"
4. Application type: **Web application**
5. Name: `The Edge Story Services`

### 1.2 Configure OAuth Consent Screen

- App name: **The Edge Story Services**
- User support email: your-email@theedgestory.org
- Authorized domains: **theedgestory.org**
- Scopes: `openid`, `email`, `profile`

### 1.3 Add Authorized Redirect URIs

Add ALL of these redirect URIs:

```
https://grafana.theedgestory.org/login/google
https://kafka.theedgestory.org/login/oauth2/code/google
https://s3-admin.theedgestory.org/oauth_callback
https://dev.theedgestory.org/auth/google/callback
```

### 1.4 Save Credentials

After creating, Google will show:
- **Client ID**: `123456789-abcdefghijklmnop.apps.googleusercontent.com`
- **Client Secret**: `GOCSPX-xxxxxxxxxxxxxxxxxxxx`

**Save these values securely!**

## Step 2: Deploy OAuth Secrets

### Option A: Using the setup script (Recommended)

```bash
cd /Users/dcversus/conductor/core-charts

# Set environment variables
export GOOGLE_CLIENT_ID='your-client-id-here'
export GOOGLE_CLIENT_SECRET='your-client-secret-here'

# Run setup script
./auth/setup-google-oauth.sh
```

### Option B: Manual deployment

```bash
# Create google-oauth secret in monitoring namespace (for Grafana, Kafka UI)
kubectl create secret generic google-oauth \
  --from-literal=client-id='YOUR_CLIENT_ID' \
  --from-literal=client-secret='YOUR_CLIENT_SECRET' \
  -n monitoring

# Create google-oauth secret in minio namespace
kubectl create secret generic google-oauth \
  --from-literal=client-id='YOUR_CLIENT_ID' \
  --from-literal=client-secret='YOUR_CLIENT_SECRET' \
  -n minio

# Create google-oauth secret in kubero namespace
kubectl create secret generic google-oauth \
  --from-literal=client-id='YOUR_CLIENT_ID' \
  --from-literal=client-secret='YOUR_CLIENT_SECRET' \
  -n kubero
```

## Step 3: Deploy OAuth-Enabled Services

### 3.1 Update Grafana

```bash
# Apply OAuth-enabled Grafana deployment
kubectl apply -f monitoring/deploy-grafana.yaml

# Restart Grafana to pick up changes
kubectl rollout restart statefulset/grafana -n monitoring

# Wait for rollout to complete
kubectl rollout status statefulset/grafana -n monitoring
```

**Verify:**
- Visit https://grafana.theedgestory.org
- You should see "Sign in with Google" button
- Click it and authenticate with your Google account

### 3.2 Deploy Kafka UI with OAuth

```bash
# Deploy Kafka UI with OAuth support
kubectl apply -f monitoring/deploy-kafka-ui-oauth.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=120s deployment/kafka-ui -n monitoring
```

**Verify:**
- Visit https://kafka.theedgestory.org
- You should be redirected to Google OAuth login
- After authentication, you'll have access to Kafka UI

### 3.3 Configure MinIO with OAuth

```bash
# Apply MinIO OAuth configuration
kubectl apply -f minio/minio-oauth-config.yaml

# Restart MinIO tenant to pick up changes
kubectl rollout restart statefulset/minio-tenant-pool-0 -n minio

# Wait for restart
kubectl rollout status statefulset/minio-tenant-pool-0 -n minio
```

**Verify:**
- Visit https://s3-admin.theedgestory.org
- You should see "Login with Google" option
- After authentication, you'll have admin access

### 3.4 Enable Kubero OAuth

```bash
# Apply Kubero OAuth configuration
kubectl apply -f kubero/kubero-oauth.yaml

# Restart Kubero
kubectl rollout restart deployment/kubero -n kubero

# Wait for restart
kubectl rollout status deployment/kubero -n kubero
```

**Verify:**
- Visit https://dev.theedgestory.org
- OAuth login should be required
- After authentication, you'll access Kubero dashboard

## Step 4: Verification

### Quick Test Script

```bash
# Check all OAuth secrets exist
kubectl get secret google-oauth -n monitoring
kubectl get secret google-oauth -n minio
kubectl get secret google-oauth -n kubero

# Check all services are running
kubectl get pods -n monitoring | grep -E "(grafana|kafka-ui)"
kubectl get pods -n minio | grep minio-tenant
kubectl get pods -n kubero | grep kubero

# Check ingresses
kubectl get ingress -A | grep -E "(grafana|kafka|s3-admin|dev\.theedgestory)"
```

### Manual Testing

Test each service:

1. **Grafana**: https://grafana.theedgestory.org
   - Look for "Sign in with Google" button
   - Test login flow
   - Verify you can access dashboards

2. **Kafka UI**: https://kafka.theedgestory.org
   - Should redirect to Google OAuth
   - After auth, verify cluster visibility

3. **MinIO**: https://s3-admin.theedgestory.org
   - Look for "Login with Google" option
   - Test authentication
   - Verify bucket access

4. **Kubero**: https://dev.theedgestory.org
   - Should require Google OAuth
   - Verify pipeline/app access after login

## Troubleshooting

### OAuth secrets not found

```bash
# Check if secret exists
kubectl describe secret google-oauth -n monitoring

# If missing, recreate
export GOOGLE_CLIENT_ID='your-id'
export GOOGLE_CLIENT_SECRET='your-secret'
./auth/setup-google-oauth.sh
```

### Grafana shows "Client ID or Secret missing"

```bash
# Check environment variables
kubectl get pod -n monitoring -l app=grafana -o yaml | grep -A 5 "GF_AUTH_GOOGLE"

# Restart Grafana
kubectl rollout restart statefulset/grafana -n monitoring
```

### Kafka UI OAuth not working

```bash
# Check logs
kubectl logs -n monitoring deployment/kafka-ui --tail=50

# Verify OAuth env vars
kubectl describe deployment kafka-ui -n monitoring | grep -A 10 "Environment"
```

### MinIO OAuth redirect fails

```bash
# Check MinIO tenant configuration
kubectl get tenant minio-tenant -n minio -o yaml | grep -A 10 "OPENID"

# Check MinIO logs
kubectl logs -n minio statefulset/minio-tenant-pool-0 --tail=50
```

### Kubero authentication loop

```bash
# Check Kubero logs
kubectl logs -n kubero deployment/kubero --tail=100

# Verify callback URL in Google Console matches
# https://dev.theedgestory.org/auth/google/callback

# Restart Kubero
kubectl rollout restart deployment/kubero -n kubero
```

## Security Notes

### Allowed Users

By default, OAuth is configured to allow **any Google account**.

To restrict to specific domains:

**Grafana:**
```yaml
- name: GF_AUTH_GOOGLE_ALLOWED_DOMAINS
  value: "theedgestory.org,yourdomain.com"
```

**Kafka UI:**
Add to Spring Security config in deployment

**MinIO:**
Configure in MinIO policy to restrict bucket access

### Session Management

- **Grafana**: Sessions managed by Grafana (configurable lifetime)
- **Kafka UI**: Spring Security session management
- **MinIO**: JWT tokens with configurable expiration
- **Kubero**: Express sessions with configurable timeout

### Revoke Access

To revoke a user's access:
1. Remove from Google OAuth authorized users (if domain-restricted)
2. For MinIO: Delete user policy via `mc admin policy`
3. For Grafana: Disable user in admin panel

## Rollback Procedure

If OAuth causes issues, you can quickly rollback:

### Disable Grafana OAuth

```bash
kubectl set env statefulset/grafana -n monitoring \
  GF_AUTH_GOOGLE_ENABLED=false

kubectl rollout restart statefulset/grafana -n monitoring
```

### Remove Kafka UI OAuth

```bash
kubectl delete deployment kafka-ui -n monitoring
# Redeploy without OAuth using standard config
```

### Disable MinIO OAuth

```bash
kubectl patch tenant minio-tenant -n minio --type=json \
  -p='[{"op": "remove", "path": "/spec/env"}]'

kubectl rollout restart statefulset/minio-tenant-pool-0 -n minio
```

### Disable Kubero OAuth

```bash
kubectl set env deployment/kubero -n kubero \
  KUBERO_AUTH_ENABLED=false

kubectl rollout restart deployment/kubero -n kubero
```

## Maintenance

### Rotate OAuth Credentials

1. Create new OAuth client in Google Console
2. Update secrets:

```bash
kubectl delete secret google-oauth -n monitoring
kubectl delete secret google-oauth -n minio
kubectl delete secret google-oauth -n kubero

export GOOGLE_CLIENT_ID='new-client-id'
export GOOGLE_CLIENT_SECRET='new-client-secret'
./auth/setup-google-oauth.sh
```

3. Restart all services:

```bash
kubectl rollout restart statefulset/grafana -n monitoring
kubectl rollout restart deployment/kafka-ui -n monitoring
kubectl rollout restart statefulset/minio-tenant-pool-0 -n minio
kubectl rollout restart deployment/kubero -n kubero
```

### Monitor OAuth Usage

```bash
# Check Grafana authentication logs
kubectl logs -n monitoring statefulset/grafana | grep -i oauth

# Check Kafka UI authentication
kubectl logs -n monitoring deployment/kafka-ui | grep -i oauth

# Check MinIO authentication
kubectl logs -n minio statefulset/minio-tenant-pool-0 | grep -i openid
```

## Complete Deployment Example

```bash
#!/bin/bash
# Complete OAuth setup from scratch

# 1. Set credentials
export GOOGLE_CLIENT_ID='123456789-abc.apps.googleusercontent.com'
export GOOGLE_CLIENT_SECRET='GOCSPX-xxxxxxxxxxxxxxxxxxxx'

# 2. Create secrets
./auth/setup-google-oauth.sh

# 3. Deploy all OAuth-enabled services
kubectl apply -f monitoring/deploy-grafana.yaml
kubectl apply -f monitoring/deploy-kafka-ui-oauth.yaml
kubectl apply -f minio/minio-oauth-config.yaml
kubectl apply -f kubero/kubero-oauth.yaml

# 4. Restart services
kubectl rollout restart statefulset/grafana -n monitoring
kubectl rollout restart deployment/kafka-ui -n monitoring
kubectl rollout restart statefulset/minio-tenant-pool-0 -n minio
kubectl rollout restart deployment/kubero -n kubero

# 5. Wait for all to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/kafka-ui -n monitoring \
  deployment/kubero -n kubero

kubectl wait --for=condition=ready --timeout=300s \
  pod -l app=grafana -n monitoring \
  pod -l app=minio -n minio

# 6. Verify
echo "Testing services..."
curl -I https://grafana.theedgestory.org | head -1
curl -I https://kafka.theedgestory.org | head -1
curl -I https://s3-admin.theedgestory.org | head -1
curl -I https://dev.theedgestory.org | head -1

echo "✅ OAuth deployment complete!"
echo "Visit each service and test Google login"
```

## Summary

After completing this guide, you will have:

✅ Unified Google OAuth across all services
✅ Single sign-on (SSO) experience
✅ Centralized user management via Google Workspace
✅ Secure authentication with industry standards
✅ Easy user provisioning/deprovisioning

**Next Steps:**
1. Configure domain restrictions if needed
2. Set up user roles/permissions in each service
3. Monitor authentication logs
4. Document authorized users
