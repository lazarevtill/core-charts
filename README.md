# The Edge Story - Production Infrastructure

**Pure GitOps Kubernetes Infrastructure on K3s**

🚀 Main Site: **https://theedgestory.org**  
⚙️ Platform: **K3s with ArgoCD GitOps**  
📦 Server: **46.62.223.198**

---

## 🎯 What is This?

This repository contains the complete infrastructure-as-code for The Edge Story platform. Everything runs on Kubernetes (K3s) and is managed via **ArgoCD GitOps** - meaning all deployments happen automatically when you push to Git.

###Key Features:
- ✅ **Pure GitOps**: Git push → Auto-deploy (no manual kubectl needed)
- ✅ **Zero-downtime deployments**: Rolling updates for all services
- ✅ **Cloudflare Origin CA**: Secure TLS without Let's Encrypt complexity
- ✅ **Google OAuth2 SSO**: Unified authentication across all admin services
- ✅ **Shared infrastructure**: One PostgreSQL, Redis, and Kafka for all environments

---

## 🚀 Quick Start

### First Time Setup (Fresh Server)

```bash
# 1. Clone repository
git clone https://github.com/uz0/core-charts.git
cd core-charts

# 2. Prepare Cloudflare Origin Certificate
# Get from: https://dash.cloudflare.com/ -> SSL/TLS -> Origin Server
# Save to: /tmp/cloudflare-origin.crt and /tmp/cloudflare-origin.key

# 3. Set Google OAuth credentials
export GOOGLE_CLIENT_ID="your-google-client-id"
export GOOGLE_CLIENT_SECRET="your-google-client-secret"

# 4. Run setup script
./scripts/setup.sh
```

That's it! The script will:
- Create TLS secrets in all namespaces
- Setup OAuth2 Proxy with Google authentication
- Configure authorized users
- Deploy all ArgoCD applications
- Wait for services to be ready

**Access services at:**
- ArgoCD: https://argo.theedgestory.org
- Dev App: https://core-pipeline.dev.theedgestory.org/api-docs
- Prod App: https://core-pipeline.theedgestory.org/api-docs

---

## 📖 Common Tasks

### Deploy Application Updates

```bash
# Update all applications
./scripts/deploy.sh all

# Update specific application
./scripts/deploy.sh core-pipeline-prod

# Update infrastructure
./scripts/deploy.sh infrastructure
```

### Check System Health

```bash
./scripts/healthcheck.sh
```

This shows:
- ✅ Cluster connectivity
- ✅ ArgoCD application sync status
- ✅ Pod health in all namespaces
- ✅ Ingress configuration
- ✅ TLS secrets presence

### Change Application Version

```bash
# 1. Edit the tag file
echo 'image:
  tag: "v1.2.3"' > charts/core-pipeline/prod.tag.yaml

# 2. Commit and push
git add charts/core-pipeline/prod.tag.yaml
git commit -m "release: deploy v1.2.3 to production"
git push origin main

# 3. ArgoCD auto-syncs (within 3 minutes)
# Watch at: https://argo.theedgestory.org
```

### Add Authorized User

```bash
# 1. Edit config/authorized-users.yaml
# Add email to: users, users-regex, users-list

# 2. Apply configuration
kubectl apply -f config/authorized-users.yaml

# 3. Restart OAuth2 Proxy
kubectl rollout restart deployment oauth2-proxy -n oauth2-proxy
```

---

## 🏗️ Architecture

### How It Works

```
Developer → Git Push → GitHub
                ↓
         ArgoCD (watches repo)
                ↓
      Fetches Remote Bitnami Charts
                ↓
      Renders with values.yaml
                ↓
      Deploys to Kubernetes (ordered by sync-wave)
```

### Infrastructure Components

**Shared Infrastructure** (`infrastructure` namespace):
- PostgreSQL 16.4.0 (Bitnami) - Shared database with isolated users
- Redis 20.6.0 (Bitnami) - Shared cache and queues
- Kafka 31.0.0 (Bitnami) - Message streaming
- Kafka UI - Kafka management with Google OAuth
- Cloudflared - Cloudflare Tunnel for secure ingress

**Applications:**
- `dev-core` - Development environment
- `prod-core` - Production environment (2 replicas, autoscaling)

**Platform Services:**
- `argocd` - GitOps deployment controller
- `oauth2-proxy` - Google OAuth2 authentication
- `monitoring` - Grafana for metrics visualization
- `status` - Gatus for service health monitoring
- `minio` - S3-compatible object storage

### Network Flow

```
User → Cloudflare CDN (Strict SSL)
         ↓
     Cloudflare Tunnel (HTTP)
         ↓
     nginx-ingress (TLS with cloudflare-origin-tls)
         ↓
     Services (HTTP)
```

---

## 📂 Repository Structure

```
core-charts/
├── scripts/              # Essential automation
│   ├── setup.sh         # Complete infrastructure setup
│   ├── deploy.sh        # Deploy updates via ArgoCD
│   └── healthcheck.sh   # Verify service health
│
├── config/               # Centralized configuration
│   ├── authorized-users.yaml  # OAuth user whitelist
│   ├── argocd-ingress.yaml    # ArgoCD ingress
│   └── argocd-cm-patch.yaml   # ArgoCD config
│
├── argocd-apps/          # ArgoCD Application CRDs
│   ├── infrastructure.yaml    # Infrastructure (wave 1)
│   ├── oauth2-proxy.yaml      # OAuth2 (wave 0)
│   ├── core-pipeline-dev.yaml # Dev app (wave 2)
│   └── core-pipeline-prod.yaml# Prod app (wave 2)
│
├── charts/               # Helm charts
│   ├── infrastructure/  # Bitnami charts + custom
│   └── core-pipeline/   # Application chart
│
└── oauth2-proxy/         # OAuth2 Proxy deployment
```

See [SERVICES.md](./SERVICES.md) for complete service directory.

---

## 🔒 Security

### Authentication
- **Google OAuth2** via OAuth2 Proxy for admin services
- **Whitelist-based** access (see `config/authorized-users.yaml`)
- **Single Sign-On** across all services (`.theedgestory.org` cookie)

### TLS/SSL
- **Cloudflare Origin CA** certificates (valid until 2040)
- **Strict SSL mode** - Full encryption end-to-end
- **No Let's Encrypt** - Static certificates, no auto-renewal complexity

### Network Security
- **Cloudflare Tunnel** - No exposed server IP, no inbound ports
- **DDoS protection** at Cloudflare edge
- **Namespace isolation** for dev/prod environments
- **Credential isolation** - Separate DB users per environment

### Secrets Management
- **Kubernetes Secrets** only (never in Git)
- **GitHub push protection** blocks accidental secret commits
- **Auto-generated passwords** for infrastructure services

---

## 🔧 Troubleshooting

### ArgoCD Not Syncing

```bash
# Check application status
kubectl get applications -n argocd

# View sync errors
kubectl describe application <app-name> -n argocd

# Force sync
./scripts/deploy.sh <app-name>
```

### Pod CrashLoopBackOff

```bash
# View logs
kubectl logs -n <namespace> <pod-name>

# View previous container logs
kubectl logs -n <namespace> <pod-name> --previous

# Describe for events
kubectl describe pod -n <namespace> <pod-name>
```

### Can't Access Service

```bash
# Check ingress
kubectl get ingress -A

# Check TLS secret
kubectl get secret cloudflare-origin-tls -n <namespace>

# Test internal connectivity
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -v http://<service-name>.<namespace>.svc.cluster.local
```

### Database Connection Issues

```bash
# Check PostgreSQL
kubectl get pods -n infrastructure -l app.kubernetes.io/name=postgresql

# Get credentials
kubectl get secret -n dev-core postgres-core-pipeline-dev-secret -o yaml

# Test connection
kubectl exec -it -n infrastructure <postgres-pod> -- \
  psql -U core_dev_user -d core_dev_db
```

---

## 📚 Additional Resources

- **[SERVICES.md](./SERVICES.md)** - Complete service directory with URLs
- **[CLAUDE.md](./CLAUDE.md)** - Technical documentation for AI assistants
- **[argocd-apps/README.md](./argocd-apps/README.md)** - ArgoCD application details
- **[config/README.md](./config/README.md)** - Configuration file documentation

---

## 🎯 Service URLs

| Service | URL | Description |
|---------|-----|-------------|
| **ArgoCD** | https://argo.theedgestory.org | GitOps deployment dashboard |
| **Kafka UI** | https://kafka.theedgestory.org | Kafka management (OAuth protected) |
| **Grafana** | https://grafana.theedgestory.org | Metrics visualization |
| **MinIO** | https://s3-admin.theedgestory.org | S3-compatible storage admin |
| **Gatus** | https://status.theedgestory.org | Service status page |
| **Dev API** | https://core-pipeline.dev.theedgestory.org/api-docs | Development environment |
| **Prod API** | https://core-pipeline.theedgestory.org/api-docs | Production environment |

### Get ArgoCD Admin Password

```bash
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

---

## 🤝 Contributing

This is a production infrastructure repository. All changes should:
1. Be tested in dev environment first
2. Follow GitOps principles (commit to Git, let ArgoCD deploy)
3. Be reviewed before merging to main
4. Update documentation if user-facing changes

---

## 📝 License

Private infrastructure repository - © The Edge Story

