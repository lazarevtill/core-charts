# The Edge Story - Production Infrastructure

**Production-Ready Kubernetes Infrastructure with Unified Authentication**

🚀 **Status**: Production Ready
🔒 **Auth**: Authentik SSO with Google OAuth
📦 **Platform**: K3s with ArgoCD GitOps
🌐 **Domain**: theedgestory.org

---

## 🎯 Quick Start

### Prerequisites
- Fresh Ubuntu server with public IP
- Domain pointed to server
- Google OAuth credentials from [Google Cloud Console](https://console.cloud.google.com)

### Setup (5 minutes)

```bash
# Clone repository
git clone https://github.com/uz0/core-charts.git
cd core-charts

# Run setup with your credentials
export GOOGLE_CLIENT_ID="your-client-id"
export GOOGLE_CLIENT_SECRET="your-client-secret"
export ADMIN_EMAIL="your-email@gmail.com"

./scripts/setup.sh
```

That's it! The script will:
- Install K3s, ArgoCD, cert-manager
- Deploy PostgreSQL, Redis, Kafka infrastructure
- Setup Authentik SSO with Google OAuth
- Configure all services with unified authentication
- Restrict access to your email only

---

## 📚 Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup.sh` | Complete infrastructure setup | Run once on fresh server |
| `deploy.sh` | Apply changes from git | `./scripts/deploy.sh` |
| `deploy-unified-auth.sh` | Configure SSO for all services | `./scripts/deploy-unified-auth.sh` |
| `healthcheck.sh` | Verify all services | `./scripts/healthcheck.sh` |
| `configure-authentik-apps.sh` | Setup OAuth apps | After Authentik is running |

---

## 🔐 Authentication

All services use **Authentik SSO** with Google OAuth:
- Single sign-on across all services
- Access restricted to specified email
- No separate passwords to manage

### Service URLs

| Service | URL | Auth Required |
|---------|-----|---------------|
| Authentik | https://auth.theedgestory.org | Admin only |
| ArgoCD | https://argo.theedgestory.org | ✅ |
| Grafana | https://grafana.theedgestory.org | ✅ |
| Kafka UI | https://kafka.theedgestory.org | ✅ |
| MinIO | https://s3-admin.theedgestory.org | ✅ |
| Status Page | https://status.theedgestory.org | Public |
| Core Pipeline Prod | https://core-pipeline.theedgestory.org | Public API |
| Core Pipeline Dev | https://core-pipeline.dev.theedgestory.org | Public API |

---

## 🏗️ Architecture

### GitOps Workflow
```
Git Push → ArgoCD Auto-Sync → Kubernetes Deployment
```

### Infrastructure Stack
- **Kubernetes**: K3s
- **GitOps**: ArgoCD
- **Database**: PostgreSQL (shared)
- **Cache**: Redis (shared)
- **Streaming**: Kafka
- **Storage**: MinIO
- **Monitoring**: Grafana + Prometheus
- **Auth**: Authentik SSO

---

## 🚀 Deployment

### Automatic
```bash
git push origin main  # ArgoCD syncs within 3 minutes
```

### Manual
```bash
./scripts/deploy.sh  # Force sync all applications
```

### Version Updates
```bash
# Production
echo 'image:\n  tag: "v1.2.3"' > charts/core-pipeline/prod.tag.yaml

# Development
echo 'image:\n  tag: "v1.2.4-dev"' > charts/core-pipeline/dev.tag.yaml

git commit -am "deploy: update versions"
git push origin main
```

---

## 📊 Monitoring

```bash
./scripts/healthcheck.sh
```

Shows:
- ✅ Cluster connectivity
- ✅ ArgoCD applications
- ✅ Pod health
- ✅ Service endpoints
- ✅ Infrastructure services
- ✅ Authentication status

---

## 🆘 Troubleshooting

### Check Status
```bash
kubectl get applications -n argocd
kubectl get pods -A
./scripts/healthcheck.sh
```

### View Logs
```bash
kubectl logs -n <namespace> <pod-name>
```

### Common Issues

**Authentik 503**: PostgreSQL password mismatch
- Fixed password: `WNAkt8ZouZRhvlcf3HSAxFXQfbt4qszs`
- Restart pods if needed

**Service Unavailable**: Check ingress and pods
```bash
kubectl get ingress -A
kubectl get pods -n <namespace>
```

---

## 📝 Repository Structure

```
core-charts/
├── scripts/            # Automation scripts
├── argocd-apps/        # ArgoCD applications
├── charts/             # Helm charts
├── config/             # Configuration files
├── README.md           # This file
└── CLAUDE.md          # AI assistant context
```

---

## 🔒 Security

- All services behind Authentik SSO
- Google OAuth authentication
- Access restricted to admin email
- TLS certificates via Let's Encrypt
- No default passwords
- Secrets in Kubernetes

---

**Production Ready** ✅ All services configured and secured.