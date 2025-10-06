# Deployment Guide - The Edge Story Infrastructure

**Complete setup guide for production Kubernetes infrastructure**

---

## 📋 Prerequisites

- K3s cluster running on server (46.62.223.198)
- kubectl configured to access the cluster
- DNS records pointing to server IP
- GitHub repository access (uz0/core-charts)

---

## 🚀 Initial Setup (First Time Only)

### 1. Clone Repository on Server

```bash
ssh root@46.62.223.198
cd /root
git clone https://github.com/uz0/core-charts.git
cd core-charts
```

### 2. Deploy Platform Services

**ArgoCD (GitOps Platform):**
```bash
# ArgoCD should already be deployed
# Check status:
kubectl get pods -n argocd

# If not deployed, install:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**cert-manager (TLS Certificates):**
```bash
# Check if installed:
kubectl get pods -n cert-manager

# Apply Let's Encrypt ClusterIssuer:
kubectl apply -f cert-manager/letsencrypt-issuer.yaml
```

**OAuth2 Proxy (Authentication):**
```bash
# Deploy OAuth2 Proxy:
export GOOGLE_CLIENT_ID='YOUR_GOOGLE_CLIENT_ID'
export GOOGLE_CLIENT_SECRET='YOUR_GOOGLE_CLIENT_SECRET'
bash setup-oauth2.sh

# Note: Use existing credentials from oauth2-proxy secret if already deployed
```

### 3. Configure ArgoCD

```bash
# Apply ArgoCD ingress:
kubectl apply -f argocd-config/argocd-ingress.yaml

# Add navigation links to ArgoCD:
kubectl create configmap argocd-cm -n argocd --dry-run=client -o yaml | kubectl apply -f -

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

kubectl rollout restart deployment argocd-server -n argocd
```

### 4. Deploy ArgoCD Applications

```bash
# Deploy all ArgoCD app definitions:
kubectl apply -f argocd-apps/

# Verify apps are created:
kubectl get applications -n argocd
```

### 5. Create Kafka UI OAuth2 Secret

```bash
# Create secret for Kafka UI:
bash create-kafka-ui-oauth2-secret.sh
```

### 6. Wait for Infrastructure to Deploy

```bash
# Watch ArgoCD sync infrastructure:
kubectl get applications -n argocd -w

# Watch infrastructure pods:
kubectl get pods -n infrastructure -w

# Should see:
# - infrastructure-postgresql-0 (Running)
# - infrastructure-redis-master-0 (Running)
# - kafka-ui (Running)
```

---

## 🌐 Service URLs

After deployment, all services are accessible:

### Public Services (No Authentication)

| Service | URL | Purpose |
|---------|-----|---------|
| Landing Page | https://theedgestory.org | Main website |
| Status Page | https://status.theedgestory.org | Uptime monitoring |
| Dev Pipeline | https://core-pipeline.dev.theedgestory.org/api-docs | Development API |
| Prod Pipeline | https://core-pipeline.theedgestory.org/api-docs | Production API |

### Admin Services (OAuth2 Protected - dcversus@gmail.com only)

| Service | URL | Purpose |
|---------|-----|---------|
| ArgoCD | https://argo.theedgestory.org | GitOps deployment dashboard |
| Grafana | https://grafana.theedgestory.org | Metrics & dashboards |
| Prometheus | https://prometheus.theedgestory.org | Metrics collection |
| Kafka UI | https://kafka.theedgestory.org | Kafka topic management |
| MinIO Console | https://s3-admin.theedgestory.org | S3 storage admin |

---

## 🔄 Day-to-Day Operations

### Deploy New Application Version

```bash
# Update image tag:
cd /root/core-charts
nano charts/core-pipeline/dev.tag.yaml
# Change: tag: "v1.2.3"

# Commit and push:
git add charts/core-pipeline/dev.tag.yaml
git commit -m "deploy: core-pipeline dev v1.2.3"
git push origin main

# ArgoCD auto-syncs within 3 minutes
# Monitor: https://argo.theedgestory.org
```

### Update Infrastructure Configuration

```bash
# Edit infrastructure config:
nano charts/infrastructure/values.yaml

# Commit and push:
git add charts/infrastructure/values.yaml
git commit -m "config: update PostgreSQL memory"
git push origin main

# ArgoCD auto-syncs
```

### Check Service Status

```bash
# All pods:
kubectl get pods -A

# Infrastructure:
kubectl get pods -n infrastructure

# Applications:
kubectl get pods -n dev-core
kubectl get pods -n prod-core

# Ingresses:
kubectl get ingress -A | grep theedgestory.org

# Certificates:
kubectl get certificates -A
```

### View Logs

```bash
# Application logs:
kubectl logs -n dev-core -l app=core-pipeline --tail=100 -f
kubectl logs -n prod-core -l app=core-pipeline --tail=100 -f

# Infrastructure logs:
kubectl logs -n infrastructure -l app=kafka-ui
kubectl logs -n infrastructure -l app.kubernetes.io/name=postgresql
```

---

## 🔧 Troubleshooting

### Infrastructure OutOfSync

```bash
# Manual sync:
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

### TLS Certificate Not Issuing

```bash
# Check certificate status:
kubectl describe certificate <name> -n <namespace>

# Check cert-manager logs:
kubectl logs -n cert-manager -l app=cert-manager

# Verify DNS points to 46.62.223.198:
dig +short argo.theedgestory.org
```

### Pod CrashLoopBackOff

```bash
# Check pod logs:
kubectl logs <pod-name> -n <namespace> --previous

# Check pod events:
kubectl describe pod <pod-name> -n <namespace>

# Check resource limits:
kubectl top pods -n <namespace>
```

### OAuth2 Not Working

```bash
# Check OAuth2 Proxy:
kubectl get pods -n oauth2-proxy
kubectl logs -n oauth2-proxy -l app=oauth2-proxy

# Verify ingress has auth annotations:
kubectl get ingress <name> -n <namespace> -o yaml | grep auth
```

---

## 🧹 Maintenance Tasks

### Clean Up Old Resources

```bash
cd /root/core-charts
bash fix-argocd-and-cleanup-v2.sh
```

### Update DNS Records

All domains should point to `46.62.223.198`:
- argo.theedgestory.org
- grafana.theedgestory.org
- prometheus.theedgestory.org
- kafka.theedgestory.org
- status.theedgestory.org
- s3-admin.theedgestory.org
- core-pipeline.dev.theedgestory.org
- core-pipeline.theedgestory.org
- theedgestory.org

**Set in Cloudflare:**
- Proxy status: DNS only (gray cloud)
- Type: A record
- Value: 46.62.223.198

---

## 📊 Architecture Summary

```
GitHub (core-charts repo)
    ↓ (webhook / 3min polling)
ArgoCD (auto-sync enabled)
    ↓ (deploys Helm charts)
Kubernetes Cluster
    ├── infrastructure/ (PostgreSQL, Redis, Kafka UI)
    ├── dev-core/ (core-pipeline-dev)
    ├── prod-core/ (core-pipeline-prod)
    ├── argocd/ (GitOps platform)
    ├── cert-manager/ (TLS automation)
    ├── oauth2-proxy/ (Authentication)
    └── monitoring/ (Grafana, Prometheus)
```

**Key Principles:**
- ✅ Git is single source of truth
- ✅ No manual kubectl for managed resources
- ✅ ArgoCD auto-syncs on git push
- ✅ Secrets never in Git
- ✅ OAuth2 on all admin services

---

## 📚 Additional Resources

- **ArgoCD Docs:** https://argo-cd.readthedocs.io/
- **Helm Docs:** https://helm.sh/docs/
- **Kubernetes Docs:** https://kubernetes.io/docs/

---

**Last Updated:** October 2025
**Infrastructure Version:** v1.0
