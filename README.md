# The Edge Story - Production Infrastructure

**GitOps-managed Kubernetes infrastructure on K3s**

Main Site: **https://theedgestory.org**
Platform: **KubeSphere v4.1.3 on K3s**

---

## 🚀 Quick Start

### First Time Setup

```bash
# 1. Clone repository on your K3s server
git clone https://github.com/uz0/core-charts.git
cd core-charts

# 2. Create OAuth2 secret for Kafka UI
bash create-kafka-ui-oauth2-secret.sh

# 3. Deploy ArgoCD applications
kubectl apply -f argocd-apps/

# 4. ArgoCD will auto-sync and deploy everything from Git
```

**That's it!** ArgoCD watches the Git repository and automatically deploys changes.

---

## 📖 User Stories

### "I want to deploy my application"

**Scenario:** You have a new version of core-pipeline to deploy to dev or production.

```bash
# 1. Update image tag in the repository
cd core-charts
nano charts/core-pipeline/dev.tag.yaml   # or prod.tag.yaml

# 2. Commit and push
git add charts/core-pipeline/dev.tag.yaml
git commit -m "deploy: core-pipeline dev v1.2.3"
git push origin main

# 3. ArgoCD auto-syncs within 3 minutes
# Watch deployment at: https://argo.theedgestory.org
```

**No manual kubectl commands needed!** Git push triggers deployment automatically.

---

### "I want to access admin services"

**Scenario:** You need to access ArgoCD, Grafana, or Kafka UI.

**All admin services are protected with Google OAuth2 SSO:**

| Service | URL | What It Does |
|---------|-----|--------------|
| **ArgoCD** | https://argo.theedgestory.org | GitOps deployment dashboard |
| **Grafana** | https://grafana.theedgestory.org | Metrics & monitoring |
| **Kafka UI** | https://kafka.theedgestory.org | Kafka topic management |
| **Prometheus** | https://prometheus.theedgestory.org | Metrics collection |

**Access:**
1. Visit any admin URL
2. Click "Sign in with Google"
3. Login with `dcversus@gmail.com` (only authorized email)
4. You're in! 🎉

**Security:** All other emails are automatically rejected with "Access Denied" error.

---

### "I want to update infrastructure"

**Scenario:** You need to change PostgreSQL, Redis, or Kafka configuration.

```bash
# 1. Edit infrastructure chart values
cd core-charts
nano charts/infrastructure/values.yaml

# 2. Commit and push
git add charts/infrastructure/values.yaml
git commit -m "config: increase PostgreSQL memory to 1Gi"
git push origin main

# 3. ArgoCD auto-syncs and applies changes
# Monitor at: https://argo.theedgestory.org
```

**Infrastructure services:**
- PostgreSQL 18.0.7 (Bitnami) - Shared database with dev/prod isolation
- Redis 23.0.10 (Bitnami) - Cache and sessions
- Kafka UI - Web interface for Kafka management

---

### "I want to check application logs"

**Scenario:** Your application is having issues and you need to debug.

**Option 1: Via CLI**
```bash
# Development environment
kubectl logs -n dev-core -l app=core-pipeline --tail=100 -f

# Production environment
kubectl logs -n prod-core -l app=core-pipeline --tail=100 -f
```

**Option 2: Via Grafana**
1. Visit https://grafana.theedgestory.org
2. Login with Google OAuth2
3. Explore → Logs → Select namespace and pod

---

### "I want to rollback a deployment"

**Scenario:** The latest deployment broke something, need to rollback.

```bash
# 1. Revert the commit that caused the issue
git revert HEAD
git push origin main

# 2. ArgoCD auto-syncs to previous version
# Or manually sync in ArgoCD UI to a specific Git revision
```

**ArgoCD keeps full deployment history** - you can rollback to any Git commit.

---

## 🏗️ Architecture

### GitOps Workflow

```
Developer
    ↓ (git push)
GitHub Repository (core-charts)
    ↓ (webhook / 3min polling)
ArgoCD (auto-sync enabled)
    ↓ (applies Kubernetes manifests)
Kubernetes Cluster
    ├── infrastructure/ (PostgreSQL, Redis, Kafka UI)
    ├── dev-core/ (core-pipeline-dev)
    └── prod-core/ (core-pipeline-prod)
```

**Key Principle:** Git is the single source of truth. All changes go through Git.

### Namespace Structure

| Namespace | Purpose | Services |
|-----------|---------|----------|
| `infrastructure` | Shared infrastructure | PostgreSQL, Redis, Kafka UI |
| `dev-core` | Development apps | core-pipeline-dev |
| `prod-core` | Production apps | core-pipeline-prod (2 replicas) |
| `argocd` | GitOps platform | ArgoCD server & controllers |
| `cert-manager` | TLS certificates | Let's Encrypt automation |
| `oauth2-proxy` | Authentication | Google OAuth2 SSO |
| `kube-system` | System services | nginx-ingress, CoreDNS |

### Security Architecture

**Multi-layer OAuth2 Protection:**

```
User → Nginx Ingress (TLS)
         → OAuth2 Proxy (validates Google login)
           → Application (validates email whitelist)
```

**Layer 1 - Nginx Ingress:**
- TLS termination (Let's Encrypt certificates)
- Routes requests to OAuth2 Proxy for auth check

**Layer 2 - OAuth2 Proxy:**
- Google OAuth2 authentication
- Email whitelist: `dcversus@gmail.com` only
- Sets authentication headers for downstream services

**Layer 3 - Applications:**
- ArgoCD: Dex authproxy reads email headers → RBAC grants admin role
- Kafka UI: Native OAuth2 integration with email regex validation
- Grafana: Auth proxy mode with auto-login

**Result:** Unauthorized users cannot access admin services at all.

---

## 📁 Repository Structure

```
core-charts/
├── README.md                           # This file - user guide
├── CLAUDE.md                           # AI assistant context & instructions
│
├── argocd-apps/                        # ArgoCD Application definitions
│   ├── infrastructure.yaml             # Shared infra (sync-wave: 1)
│   ├── core-pipeline-dev.yaml          # Dev app (sync-wave: 2)
│   ├── core-pipeline-prod.yaml         # Prod app (sync-wave: 2)
│   └── oauth2-proxy.yaml               # OAuth2 authentication
│
├── charts/                             # Helm charts
│   ├── infrastructure/                 # Infrastructure umbrella chart
│   │   ├── Chart.yaml                  # Bitnami dependencies (PostgreSQL, Redis)
│   │   ├── values.yaml                 # Configuration
│   │   └── templates/                  # Kafka UI resources
│   │       ├── kafka-ui-deployment.yaml
│   │       ├── kafka-ui-service.yaml
│   │       ├── kafka-ui-configmap.yaml
│   │       └── kafka-ui-ingress.yaml
│   │
│   └── core-pipeline/                  # Application chart
│       ├── Chart.yaml
│       ├── values.yaml                 # Base config
│       ├── values-dev.yaml             # Dev overrides
│       ├── values-prod.yaml            # Prod overrides
│       ├── dev.tag.yaml                # Dev image tag (deploy trigger)
│       ├── prod.tag.yaml               # Prod image tag (deploy trigger)
│       └── templates/                  # Kubernetes manifests
│
├── cert-manager/                       # TLS certificate configuration
│   └── letsencrypt-issuer.yaml         # Let's Encrypt ClusterIssuer
│
├── oauth2-proxy/                       # OAuth2 authentication
│   └── deployment.yaml                 # OAuth2 Proxy resources
│
├── setup-oauth2.sh                     # Initial OAuth2 setup script
└── create-kafka-ui-oauth2-secret.sh    # Kafka UI OAuth2 secret helper
```

---

## 🔧 Common Operations

### Deploy New Application Version

```bash
# Update image tag
echo 'tag: "v1.2.3"' > charts/core-pipeline/dev.tag.yaml

# Commit and push
git add charts/core-pipeline/dev.tag.yaml
git commit -m "deploy: core-pipeline dev v1.2.3"
git push origin main
```

### Check Deployment Status

```bash
# Via ArgoCD UI
open https://argo.theedgestory.org

# Via CLI
kubectl get applications -n argocd
kubectl get pods -A
```

### Update Infrastructure Configuration

```bash
# Edit values
nano charts/infrastructure/values.yaml

# Commit and push (ArgoCD auto-syncs)
git add charts/infrastructure/values.yaml
git commit -m "config: update PostgreSQL settings"
git push origin main
```

### Manual Sync (if auto-sync is slow)

```bash
# Sync specific application
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# Or use ArgoCD UI: Applications → infrastructure → SYNC
```

---

## 🌐 Access Points

### Public Services

| Service | URL | Description |
|---------|-----|-------------|
| **Landing Page** | https://theedgestory.org | Main website |
| **Core Pipeline Dev** | https://core-pipeline.dev.theedgestory.org/api-docs | Development API |
| **Core Pipeline Dev (alt)** | https://core-pipeline-dev.theedgestory.org/api-docs | Alternative dev URL |
| **Core Pipeline Prod** | https://core-pipeline.theedgestory.org/api-docs | Production API |

### Admin Services (OAuth2 Protected)

| Service | URL | Credentials |
|---------|-----|-------------|
| **ArgoCD** | https://argo.theedgestory.org | Google OAuth2 (dcversus@gmail.com) |
| **Grafana** | https://grafana.theedgestory.org | Google OAuth2 (dcversus@gmail.com) |
| **Kafka UI** | https://kafka.theedgestory.org | Google OAuth2 (dcversus@gmail.com) |
| **Prometheus** | https://prometheus.theedgestory.org | Google OAuth2 (dcversus@gmail.com) |

---

## 🆘 Troubleshooting

### Application Not Deploying

**Check ArgoCD sync status:**
```bash
kubectl get application <app-name> -n argocd -o yaml
kubectl describe application <app-name> -n argocd
```

**Common issues:**
- Git repository not accessible (check ArgoCD logs)
- Helm chart syntax errors (check sync status)
- Resource limits exceeded (check pod status)

### Can't Access Admin Services

**Check OAuth2 Proxy:**
```bash
kubectl get pods -n oauth2-proxy
kubectl logs -n oauth2-proxy -l app=oauth2-proxy
```

**Check ingress:**
```bash
kubectl get ingress -A
kubectl describe ingress <name> -n <namespace>
```

**Check TLS certificates:**
```bash
kubectl get certificates -A
kubectl describe certificate <name> -n <namespace>
```

### Pod Not Starting

**Check pod status:**
```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Common issues:**
- Image pull errors (check imagePullSecrets)
- Resource limits (check node resources)
- Configuration errors (check ConfigMaps/Secrets)

---

## 📚 Documentation

- **ArgoCD:** https://argo-cd.readthedocs.io/
- **Helm Charts:** https://helm.sh/docs/
- **Kubernetes:** https://kubernetes.io/docs/
- **KubeSphere:** https://kubesphere.io/docs/v4.1/

---

## 🔐 Security Best Practices

✅ **Secrets never in Git** - Use Kubernetes Secrets, reference from Helm charts
✅ **OAuth2 for all admin services** - No default passwords, Google SSO only
✅ **TLS everywhere** - Let's Encrypt certificates via cert-manager
✅ **Email whitelist** - Only `dcversus@gmail.com` can access admin services
✅ **GitOps workflow** - All changes reviewed in Git before deployment
✅ **Resource limits** - All pods have CPU/memory limits
✅ **Network policies** - Namespace isolation (when configured)

---

**Infrastructure Version:** v1.0
**Last Updated:** October 2025
**License:** MIT
