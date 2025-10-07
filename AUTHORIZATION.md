# Centralized Authorization Configuration

This document describes the centralized authorization system for all SSO-enabled applications.

## Overview

All applications (ArgoCD, Grafana, MinIO, Kafka UI, Prometheus) use a centralized authorization list stored in the `authorized-users` ConfigMap in the `infrastructure` namespace.

**Currently authorized user:** `dcversus@gmail.com`

## Architecture

```
k8s/shared-config/authorized-users.yaml
  ↓
  Applied to cluster
  ↓
ConfigMap: infrastructure/authorized-users
  ↓
  Referenced by:
  ├── ArgoCD (Dex allowedEmailAddresses)
  ├── Grafana (allowed_emails in auth.google)
  ├── MinIO (MINIO_IDENTITY_OPENID_CLAIM_USERINFO)
  ├── Kafka UI (allowedEmailPattern)
  └── Prometheus (via OAuth2 Proxy)
```

## Current Configuration

### ArgoCD
- **Location:** ConfigMap `argocd-cm` in namespace `argocd`
- **Field:** `dex.config` → `connectors[0].config.allowedEmailAddresses`
- **Value:** `["dcversus@gmail.com"]`
- **RBAC:** ConfigMap `argocd-rbac-cm` grants admin role to dcversus@gmail.com

### Kafka UI
- **Location:** Helm values in `charts/infrastructure/values.yaml`
- **Field:** `kafkaUI.oauth2.allowedEmailPattern`
- **Value:** `^dcversus@gmail\.com$`
- **OAuth2 Secret:** `kafka-ui-oauth2-secret` (manually created)

### Grafana
- **Status:** Needs Google OAuth2 configuration
- **Will use:** `auth.google.allowed_emails` or `auth.generic_oauth`

### MinIO
- **Status:** Needs Google OAuth2 configuration
- **Will use:** OpenID Connect with email claim filtering

### Prometheus
- **Status:** Can use OAuth2 Proxy or direct Google OAuth

## Adding New Users

### Method 1: Manual (Recommended for understanding)

1. **Edit the ConfigMap:**
   ```bash
   kubectl edit configmap authorized-users -n infrastructure
   ```

   Add the new email to all three fields:
   - `users`: Add to comma-separated list
   - `users-regex`: Add with proper escaping (e.g., `^newuser@gmail\.com$`)
   - `users-list`: Add as YAML list item

2. **Update ArgoCD:**
   ```bash
   # Add to allowedEmailAddresses
   kubectl patch configmap argocd-cm -n argocd --type merge -p '{
     "data": {
       "dex.config": "connectors:\n- type: google\n  id: google\n  name: Google\n  config:\n    clientID: $dex.google.clientID\n    clientSecret: $dex.google.clientSecret\n    redirectURI: https://argo.theedgestory.org/api/dex/callback\n    allowedEmailAddresses:\n    - dcversus@gmail.com\n    - newuser@example.com\n"
     }
   }'

   # Add to RBAC (if admin access needed)
   kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '{
     "data": {
       "policy.csv": "g, dcversus@gmail.com, role:admin\ng, newuser@example.com, role:admin\n"
     }
   }'
   ```

3. **Update Kafka UI:**
   Edit `charts/infrastructure/values.yaml`:
   ```yaml
   kafkaUI:
     oauth2:
       allowedEmailPattern: "^(dcversus@gmail\\.com|newuser@example\\.com)$"
   ```

4. **Restart affected services:**
   ```bash
   kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-dex-server
   kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-server
   kubectl delete pod -n infrastructure -l app=kafka-ui
   ```

### Method 2: Using the helper script

```bash
./add-authorized-user.sh newuser@example.com
```

This will print the commands you need to run (but won't execute them automatically for safety).

## Security Notes

1. **Google OAuth2 credentials are stored as Kubernetes Secrets** (not in Git)
2. **Only emails in the authorized list can authenticate**
3. **All traffic goes through Cloudflare Tunnel** (no direct server exposure)
4. **TLS is terminated at nginx-ingress** (handled by cert-manager + Let's Encrypt)

## OAuth2 Secrets

Each application has its own OAuth2 client credentials:

- **ArgoCD:** `argocd-secret` (namespace: `argocd`)
  - Fields: `dex.google.clientID`, `dex.google.clientSecret`
  - Redirect URI: `https://argo.theedgestory.org/api/dex/callback`

- **Kafka UI:** `kafka-ui-oauth2-secret` (namespace: `infrastructure`)
  - Fields: `client-id`, `client-secret`
  - Redirect URI: `https://kafka.theedgestory.org/login/oauth2/code/google`

- **Grafana:** TBD
  - Redirect URI: `https://grafana.theedgestory.org/login/google`

- **MinIO:** TBD
  - Redirect URI: `https://s3-admin.theedgestory.org/oauth_callback`

## Troubleshooting

### User can't log in to ArgoCD
1. Check Dex logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-dex-server`
2. Verify email in allowedEmailAddresses: `kubectl get configmap argocd-cm -n argocd -o yaml`
3. Check RBAC: `kubectl get configmap argocd-rbac-cm -n argocd -o yaml`

### User sees "Access Denied" in Kafka UI
1. Check allowedEmailPattern in values.yaml
2. Verify OAuth2 secret exists: `kubectl get secret kafka-ui-oauth2-secret -n infrastructure`
3. Check Kafka UI logs: `kubectl logs -n infrastructure -l app=kafka-ui`

### Changes not taking effect
1. Restart the affected pods to pick up ConfigMap changes
2. ConfigMaps are cached by pods - restart is required
