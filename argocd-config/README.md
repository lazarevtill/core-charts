# ArgoCD Configuration

**Purpose:** Manual configuration for ArgoCD (not managed by Helm chart)

## Why Separate?

ArgoCD manages itself and other applications. Its ConfigMaps and ingress should not be managed by the infrastructure Helm chart to avoid conflicts and circular dependencies.

## Initial Setup (One-Time)

### 1. Create ArgoCD Ingress

```bash
cd /root/core-charts
kubectl apply -f argocd-config/argocd-ingress.yaml
```

This creates:
- Ingress at `argo.theedgestory.org`
- OAuth2 Proxy authentication
- TLS certificate via Let's Encrypt

### 2. Add Navigation Links to ArgoCD

```bash
# Create argocd-cm if it doesn't exist
kubectl create configmap argocd-cm -n argocd --dry-run=client -o yaml | kubectl apply -f -

# Add external navigation links to ArgoCD UI
kubectl patch configmap argocd-cm -n argocd --type merge --patch '
data:
  ui.externalLinks: |
    - title: "🏠 The Edge Story"
      url: "https://theedgestory.org"
    - title: "✅ Status Page"
      url: "https://status.theedgestory.org"
    - title: "📊 Grafana"
      url: "https://grafana.theedgestory.org"
    - title: "📈 Prometheus"
      url: "https://prometheus.theedgestory.org"
    - title: "📨 Kafka UI"
      url: "https://kafka.theedgestory.org"
    - title: "💾 MinIO Console"
      url: "https://s3-admin.theedgestory.org"
    - title: "🚀 Dev Pipeline"
      url: "https://core-pipeline.dev.theedgestory.org/api-docs"
    - title: "✨ Prod Pipeline"
      url: "https://core-pipeline.theedgestory.org/api-docs"
'

# Restart ArgoCD server to pick up changes
kubectl rollout restart deployment argocd-server -n argocd
```

## Verify

After setup:

```bash
# Check ingress
kubectl get ingress argocd-server -n argocd

# Check certificate (wait 2-3 minutes after ingress creation)
kubectl get certificate argocd-server-tls -n argocd

# Check ArgoCD is running
kubectl get pods -n argocd
```

Visit https://argo.theedgestory.org:
- Should see ArgoCD login page
- Login with Google OAuth2 (dcversus@gmail.com)
- Navigation links in top menu: 🏠 ✅ 📊 📈 📨 💾 🚀 ✨

## Files in This Directory

- `argocd-ingress.yaml` - ArgoCD server ingress (manual apply)
- `argocd-cm-patch.yaml` - Navigation links patch (reference)
- `README.md` - This file

## Notes

- ✅ ArgoCD's Dex OAuth2 is configured via OAuth2 Proxy
- ✅ RBAC is configured (dcversus@gmail.com → role:admin)
- ❌ Do NOT manage these via Helm chart (causes circular dependency)
