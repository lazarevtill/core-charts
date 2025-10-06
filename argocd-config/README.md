# ArgoCD Configuration

**Purpose:** Manual configuration patches for ArgoCD (not managed by Helm chart)

## Why separate?

ArgoCD manages itself and other applications. Its ConfigMaps should not be managed by the infrastructure Helm chart to avoid conflicts and circular dependencies.

## Apply External Links to ArgoCD

**On the server, run:**

```bash
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

After restart, visit https://argo.theedgestory.org and you should see navigation links in the top menu.

## Notes

- ArgoCD's Dex OAuth2 configuration is already set up via OAuth2 Proxy
- RBAC is already configured (dcversus@gmail.com → role:admin)
- This patch only adds navigation links
- Do NOT manage argocd-cm via Helm chart (causes conflicts)
