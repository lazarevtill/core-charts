# Configuration Files

This directory contains centralized configuration for infrastructure services.

## Files

### `authorized-users.yaml`
Central authorization list for all services with Google OAuth2 authentication.

**Services using this:**
- Kafka UI (via OAuth2 Proxy)

**To add a new user:**
```bash
# 1. Edit the file and add email to all three fields:
#    - users (comma-separated)
#    - users-regex (escaped for regex)
#    - users-list (YAML list)
#
# 2. Apply the configuration
kubectl apply -f config/authorized-users.yaml

# 3. Restart OAuth2 Proxy to pick up changes
kubectl rollout restart deployment oauth2-proxy -n oauth2-proxy
```

### `argocd-ingress.yaml`
Ingress configuration for ArgoCD server.

**Apply:**
```bash
kubectl apply -f config/argocd-ingress.yaml
```

### `argocd-cm-patch.yaml`
ConfigMap patch for ArgoCD configuration (repository settings, etc.).

**Apply:**
```bash
kubectl apply -f config/argocd-cm-patch.yaml
```

### `cert-manager/`
Certificate manager configuration (currently not used - we use Cloudflare Origin certificates).

**Note**: These files are kept for reference but are not actively used. All ingresses now use the `cloudflare-origin-tls` secret.

## Usage in Scripts

These configuration files are applied by `scripts/setup.sh` during initial setup.

For manual updates:
```bash
# Apply all configuration
kubectl apply -f config/

# Apply specific file
kubectl apply -f config/<filename>
```
