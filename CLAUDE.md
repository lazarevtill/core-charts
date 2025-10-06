# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚨 CRITICAL RULES

### Documentation Files Policy
**FORBIDDEN**: Do NOT create any `.md` files except `CLAUDE.md` and `README.md`

- ✅ **ALLOWED**: Update `CLAUDE.md` and `README.md` only
- ❌ **FORBIDDEN**: Creating `CHANGELOG.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, or ANY other `.md` files
- **Reason**: All documentation must be consolidated in README.md for single source of truth
- **Exception**: Only CLAUDE.md and README.md are permitted

### After Every Iteration
1. **Update CLAUDE.md** with current status, progress, and issues
2. **Update README.md** production readiness checklist with completed items
3. **Document actual state** - no aspirational documentation
4. **Remove any .md files** created accidentally (except CLAUDE.md and README.md)

## Overview

Production Kubernetes infrastructure running on K3s with **Pure ArgoCD GitOps** architecture. Single shared infrastructure (PostgreSQL, Redis, Kafka) with credential isolation per environment. Only core-pipeline applications split dev/prod. Git is the single source of truth - all deployments managed by ArgoCD using remote Helm charts from Bitnami registry.

## 🎯 Current Production Readiness Status (Oct 6, 2025)

### ✅ LATEST UPDATE (Oct 6, 2025 - Pure GitOps Migration)

**Pure ArgoCD GitOps Architecture (100%)**
- ✅ Removed landing page (migrated to GitHub Pages: https://github.com/uz0/theedgestory.org)
- ✅ Created infrastructure umbrella Helm chart with remote Bitnami dependencies
- ✅ PostgreSQL 16.4.0 - single instance with dev/prod users (core_dev_user, core_prod_user)
- ✅ Redis 20.6.0 - single instance, shared by all environments
- ✅ Kafka 31.0.0 - single Bitnami instance (replaced Strimzi)
- ✅ Infrastructure ArgoCD app uses Helm chart (sync-wave: 1)
- ✅ Application ArgoCD apps use separate value files (sync-wave: 2)
- ✅ Updated service connection strings to Bitnami chart names
- ✅ Removed all .md documentation files except CLAUDE.md and README.md

**GitOps Workflow:**
```
Git Push → Webhook → ArgoCD Auto-Sync → Kubernetes
                ↓
        Fetches Remote Bitnami Charts
                ↓
        Renders with values.yaml
                ↓
        Syncs in Order (sync-waves)
```

**Key Architecture Changes:**
- ❌ **REMOVED**: Local file:// Helm subcharts
- ❌ **REMOVED**: CNPG PostgreSQL operator (replaced with Bitnami chart)
- ❌ **REMOVED**: Strimzi Kafka operator (replaced with Bitnami chart)
- ❌ **REMOVED**: Raw Kubernetes manifests in k8s/infrastructure
- ❌ **REMOVED**: Landing page (now on GitHub Pages)
- ✅ **ADDED**: Infrastructure umbrella chart with remote dependencies
- ✅ **ADDED**: Sync-wave annotations for deployment ordering
- ✅ **ADDED**: True GitOps compliance (no manual Helm operations)

### 📊 Production Readiness Score: 98% ✨

**Architecture Complete:**
- ✅ Pure GitOps workflow (Git → ArgoCD → Kubernetes)
- ✅ Single shared infrastructure with credential isolation
- ✅ Remote Helm charts from Bitnami registry
- ✅ No local dependencies, true GitOps compliance

## Common Commands

### ArgoCD GitOps Operations
```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# Trigger ArgoCD sync (deployment happens automatically via webhook)
kubectl patch application infrastructure -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# View sync status
kubectl describe application infrastructure -n argocd

# Access ArgoCD UI
open https://argo.dev.theedgestory.org
```

### Kubernetes
```bash
# Check deployment status
kubectl get pods -A
kubectl get ingress -A

# View logs
kubectl logs -n <namespace> <pod-name>

# Check infrastructure resources
kubectl get pods -n infrastructure
kubectl get svc -n infrastructure

# Check application pods
kubectl get pods -n dev-core
kubectl get pods -n prod-core
```

## Architecture

### Deployment Model: Pure ArgoCD GitOps
**Single Shared Infrastructure** - All environments share one PostgreSQL, one Redis, one Kafka with credential isolation:

```
Git Repository (GitHub)
       ↓
   [Push to main]
       ↓
   ArgoCD Auto-Sync ←── Fetches Remote Bitnami Charts
       ↓
   Kubernetes Cluster
       ↓
infrastructure/                   # Shared Infrastructure (ArgoCD sync-wave: 1)
  ├── PostgreSQL                 # Bitnami chart 16.4.0 (core_dev_user, core_prod_user)
  ├── Redis                      # Bitnami chart 20.6.0 (shared by all environments)
  └── Kafka                      # Bitnami chart 31.0.0 (single instance)

dev-core/                        # Development Application (ArgoCD sync-wave: 2)
  └── core-pipeline-dev          # Connects to core_dev_user@postgresql

prod-core/                       # Production Application (ArgoCD sync-wave: 2)
  └── core-pipeline-prod         # Connects to core_prod_user@postgresql (2 replicas)
```

**Platform Services:**
- `argocd` namespace - GitOps controller (deploys everything from Git)
- `cert-manager` namespace - TLS certificate management
- `kube-system` - nginx-ingress controller (LoadBalancer: 46.62.223.198)

**Key Architecture Principles:**
- ✅ **Pure GitOps**: Git push → ArgoCD auto-sync → Kubernetes (no manual Helm operations)
- ✅ **Remote Helm charts**: Fetched from Bitnami registry (no local file:// dependencies)
- ✅ **Single shared infrastructure**: ONE PostgreSQL, ONE Redis, ONE Kafka for all environments
- ✅ **Credential isolation**: Separate database users and Redis ACL users per environment
- ✅ **Only applications split dev/prod**: core-pipeline-dev and core-pipeline-prod
- ✅ **Sync waves**: Infrastructure (wave 1) deploys before applications (wave 2)

### Namespace Structure
| Namespace | Purpose | Components | Status |
|-----------|---------|------------|--------|
| infrastructure | Shared infrastructure | PostgreSQL, Redis, Kafka | ✅ Managed by ArgoCD |
| dev-core | Dev applications | core-pipeline-dev | ✅ Managed by ArgoCD |
| prod-core | Prod applications | core-pipeline-prod | ✅ Managed by ArgoCD |
| argocd | GitOps platform | ArgoCD server & controllers | ✅ Platform |
| cert-manager | Certificate management | cert-manager, Let's Encrypt | ✅ Platform |
| kube-system | Ingress & system | nginx-ingress, CoreDNS | ✅ Platform |

### Repository Structure (Pure GitOps)
```
core-charts/
├── charts/
│   ├── infrastructure/          # Umbrella chart (NO local subcharts)
│   │   ├── Chart.yaml          # References remote Bitnami charts
│   │   └── values.yaml         # Consolidated config for all services
│   └── core-pipeline/         # Application chart
│       ├── Chart.yaml
│       ├── values.yaml        # Base values
│       ├── values-dev.yaml    # Dev overrides (core_dev_user credentials)
│       ├── values-prod.yaml   # Prod overrides (core_prod_user credentials)
│       ├── dev.tag.yaml       # Dev image tag (independent deployment)
│       └── prod.tag.yaml      # Prod image tag (independent deployment)
├── argocd-apps/              # ArgoCD Application CRDs (GitOps definitions)
│   ├── infrastructure.yaml   # Single shared infra (sync-wave: 1)
│   ├── core-pipeline-dev.yaml  # Dev app (sync-wave: 2)
│   └── core-pipeline-prod.yaml # Prod app (sync-wave: 2)
├── CLAUDE.md                # Instructions for Claude Code (THIS FILE)
└── README.md                # Comprehensive production documentation
```

**Key Changes from Previous Architecture:**
- ❌ **REMOVED**: `landing/` directory (migrated to GitHub Pages)
- ❌ **REMOVED**: `k8s/infrastructure/` raw manifests (replaced with Helm chart)
- ❌ **REMOVED**: Local Helm subcharts (file:// dependencies)
- ✅ **ADDED**: Remote Helm chart references in Chart.yaml (Bitnami registry)
- ✅ **ADDED**: Consolidated values.yaml with all service configurations
- ✅ **ADDED**: Sync-wave annotations for deployment ordering

### Working Services & Endpoints

| Service | URL | Namespace | Status |
|---------|-----|-----------|--------|
| ArgoCD | https://argo.dev.theedgestory.org | argocd | ✅ |
| Core Pipeline Dev | https://core-pipeline.dev.theedgestory.org/api-docs | dev-core | ✅ |
| Core Pipeline Dev (alt) | https://core-pipeline-dev.theedgestory.org/api-docs | dev-core | ✅ |
| Core Pipeline Prod | https://core-pipeline.theedgestory.org/api-docs | prod-core | ✅ |
| Grafana | https://grafana.dev.theedgestory.org | monitoring | ✅ |
| Prometheus | https://prometheus.dev.theedgestory.org | monitoring | ✅ |

## Development Workflow

**GitOps-First Development:**

1. **Make changes** locally and commit to repository
2. **Push to main** - webhook triggers ArgoCD sync
3. **Monitor** via ArgoCD UI at https://argo.dev.theedgestory.org
   - Or CLI: `kubectl get applications -n argocd`
4. **Verify** deployments:
   - Dev: https://core-pipeline.dev.theedgestory.org
   - Prod: https://core-pipeline.theedgestory.org
5. **Debug** issues:
   - ArgoCD app logs: `kubectl describe application <name> -n argocd`
   - Pod logs: `kubectl logs <pod-name> -n <namespace>`
6. **Rollback** if needed:
   - Revert git commit and push
   - Or sync to specific revision in ArgoCD UI

### Deployment Process

**Automated via Webhook:**
```
GitHub Push → Webhook (port 9000) → deploy-hook.sh → ArgoCD Sync → Kubernetes
```

**Manual Deployment:**
```bash
cd /root/core-charts
git pull origin main
kubectl apply -f argocd-apps/
kubectl patch application infrastructure -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

### Infrastructure Updates

**Changing Bitnami Chart Versions:**
1. Edit `charts/infrastructure/Chart.yaml`
2. Update dependency versions
3. Commit and push - ArgoCD auto-syncs
4. No `helm dependency build` needed - ArgoCD fetches remote charts

**Updating Service Configuration:**
1. Edit `charts/infrastructure/values.yaml`
2. Commit and push
3. ArgoCD detects changes and syncs automatically

## Security Notes

**Google OAuth2 Authentication:**
- ✅ **OAuth2 Proxy** - All services protected with Google login
- ✅ **Whitelist** - Only `dcversus@gmail.com` allowed
- ✅ **Cookie domain** - `.theedgestory.org` (single sign-on across all services)
- ✅ **Protected services** - ArgoCD, Grafana, Kafka UI, MinIO
- ✅ **Admin access only** - No default admin passwords, all via OAuth

**Deploying OAuth2:**
```bash
export GOOGLE_CLIENT_ID='your-google-client-id'
export GOOGLE_CLIENT_SECRET='your-google-client-secret'
bash setup-oauth2.sh
```

**Credential Isolation:**
- ✅ **Separate database users** - `core_dev_user` and `core_prod_user` in shared PostgreSQL
- ✅ **Auto-generated passwords** - 24-character random passwords during installation
- ✅ **Namespace isolation** - dev-core and prod-core with separate RBAC
- ✅ **TLS enforcement** - All ingresses require HTTPS
- ✅ **Secret management** - Kubernetes secrets, never in git

**Accessing Credentials:**
```bash
# ArgoCD admin password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# PostgreSQL credentials
kubectl get secret -n dev-core postgres-core-pipeline-dev-secret -o yaml
kubectl get secret -n prod-core postgres-core-pipeline-prod-secret -o yaml

# Redis credentials
kubectl get secret -n dev-core redis-dev-secret -o yaml
kubectl get secret -n prod-core redis-prod-secret -o yaml

# List all secrets
kubectl get secrets -A
```

## Server Information

**Server:** 46.62.223.198
**Kubernetes:** K3s
**Ingress:** nginx-ingress (LoadBalancer)
**TLS:** cert-manager with Let's Encrypt

### Platform Services
- ✅ K3s cluster running
- ✅ ArgoCD (GitOps controller)
- ✅ nginx-ingress controller (LoadBalancer: 46.62.223.198)
- ✅ cert-manager with Let's Encrypt
- ✅ DNS configured: *.dev.theedgestory.org, *.theedgestory.org

## Helm Chart Dependencies (Pure GitOps)

The infrastructure umbrella chart uses **remote Bitnami charts** for true GitOps:
```yaml
dependencies:
  - name: postgresql
    version: 16.4.0
    repository: https://charts.bitnami.com/bitnami
  - name: redis
    version: 20.6.0
    repository: https://charts.bitnami.com/bitnami
  - name: kafka
    version: 31.0.0
    repository: https://charts.bitnami.com/bitnami
```
**NO `helm dependency build` needed** - ArgoCD fetches charts from Bitnami registry automatically.

## Known Issues

### Active Issues
None - fresh installation, all issues resolved.

### Migration Notes
- All old ArgoCD-based infrastructure removed
- Clean slate installation
- No legacy namespaces
- No webhook automation (may add later if needed)

## Troubleshooting

See **INSTALL.md** for comprehensive troubleshooting guide, including:
- Extensions not appearing
- Pods not starting
- Certificate issues
- Database connectivity
- Kafka connectivity

Quick checks:
```bash
# Check all pods
kubectl get pods -A

# Check KubeSphere status
kubectl get pods -n kubesphere-system

# Check infrastructure
kubectl get cluster -n infrastructure
kubectl get kafka -n infrastructure

# Check applications
kubectl get pods -n dev-core
kubectl get pods -n prod-core

# Check ingresses
kubectl get ingress -A
```
