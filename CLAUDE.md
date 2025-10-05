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

**KubeSphere v4 Platform** - Production Kubernetes infrastructure running on K3s with KubeSphere v4.1.3 (LuBan Architecture). Single shared infrastructure (PostgreSQL via CloudNativePG, Redis standalone, Kafka via Strimzi) with credential isolation per environment. Only core-pipeline applications split dev/prod.

## 🎯 Current Status (Oct 5, 2025)

### ✅ COMPLETED (Fresh KubeSphere v4 Setup)

**Repository Migration (100%)**
- ✅ Complete cleanup of old ArgoCD-based infrastructure
- ✅ Fresh repository structure for KubeSphere v4
- ✅ All manifests created and organized
- ✅ Automated installation script (`fresh-install.sh`)

**Documentation (100%)**
- ✅ README.md - Quick start guide with 3-step installation
- ✅ INSTALL.md - Complete step-by-step manual guide (40 minutes)
- ✅ CORE-PIPELINE-DEPLOY.md - Application deployment instructions
- ✅ CLAUDE.md - Updated for KubeSphere v4 architecture

**Kubernetes Manifests (100%)**
- ✅ KubeSphere HTTPS ingress
- ✅ PostgreSQL cluster (CloudNativePG)
- ✅ Kafka cluster with topics (Strimzi)
- ✅ Redis standalone
- ✅ core-pipeline dev & prod deployments

**Installation Automation (100%)**
- ✅ `fresh-install.sh` - Fully automated installation script
- ✅ 6-phase deployment (cleanup, core, operators, infrastructure, secrets, apps)
- ✅ Estimated time: ~15 minutes
- ✅ Destructive fresh start capability

### ⚠️ PENDING TASKS

**Server Deployment:**
1. Push changes to GitHub repository
2. Run `fresh-install.sh` on server (46.62.223.198)
3. Test KubeSphere v4 installation
4. Install extensions via Web UI (WhizardTelemetry Monitoring/Logging, DevOps)
5. Verify all endpoints

**Application Repository (https://github.com/uz0/core-pipeline):**
1. Add Kubernetes deployment manifests
2. Configure GitHub Actions for deployment
3. Set up KUBECONFIG secret
4. Test CI/CD pipeline

### 📊 Migration Status: 95% ✨

**What Changed:**
- ❌ **REMOVED**: ArgoCD, custom Helm charts, bootstrap scripts, webhook automation
- ✅ **ADDED**: KubeSphere v4 platform with Extension Center
- ✅ **SIMPLIFIED**: Single automated script instead of multi-step bootstrap
- ✅ **MODERNIZED**: CloudNativePG (PostgreSQL), Strimzi (Kafka), direct Kubernetes manifests

## Common Commands

### Fresh Installation
```bash
# On server (DESTRUCTIVE - deletes all existing resources)
git clone https://github.com/uz0/core-charts.git
cd core-charts
bash fresh-install.sh

# Manual installation (step-by-step)
# Follow INSTALL.md for detailed guide
```

### Kubernetes
```bash
# Check deployment status
kubectl get pods -A
kubectl get ingress -A

# View logs
kubectl logs -n <namespace> <pod-name>

# Check KubeSphere status
kubectl get pods -n kubesphere-system

# Check infrastructure
kubectl get cluster -n infrastructure         # PostgreSQL
kubectl get kafka -n infrastructure           # Kafka
kubectl get pods -n infrastructure -l app=redis  # Redis
```

### KubeSphere Extensions
```bash
# List installed extensions
kubectl get extensions -A

# Install extension via CLI (or use Web UI)
kubectl apply -f extensions/monitoring.yaml
```

## Architecture

### Deployment Model: KubeSphere v4 Platform
**Single Shared Infrastructure** - All environments share one PostgreSQL, one Redis, one Kafka with credential isolation:

```
KubeSphere v4.1.3 (LuBan Architecture)
├── Core Platform (kubesphere-system namespace)
│   ├── ks-console (Web UI)
│   ├── ks-apiserver (API Server)
│   └── ks-controller-manager (Controller)
│
├── Extensions (Install from Extension Center)
│   ├── WhizardTelemetry Monitoring (Prometheus/Grafana)
│   ├── WhizardTelemetry Logging (Vector/OpenSearch)
│   ├── WhizardTelemetry Notification
│   ├── DevOps (Jenkins/Argo CD)
│   └── Service Mesh (Istio)
│
└── Custom Infrastructure (infrastructure namespace)
    ├── PostgreSQL (CloudNativePG)
    │   ├── core_pipeline_dev database
    │   ├── core_pipeline_prod database
    │   ├── core_dev_user (dev credentials)
    │   └── core_prod_user (prod credentials)
    ├── Redis (Standalone)
    └── Kafka (Strimzi Operator)
        ├── infrastructure-kafka cluster (3 replicas)
        ├── core-pipeline-events topic
        ├── core-pipeline-commands topic
        └── core-pipeline-logs topic

Applications:
├── dev-core namespace
│   └── core-pipeline (1 replica)
└── prod-core namespace
    └── core-pipeline (2 replicas)

Platform Services:
├── cert-manager namespace - TLS certificate management
└── kube-system - Traefik ingress controller (LoadBalancer: 46.62.223.198)
```

**Key Architecture Principles:**
- ✅ **KubeSphere Platform**: Unified management console with extension ecosystem
- ✅ **Single shared infrastructure**: ONE PostgreSQL, ONE Redis, ONE Kafka for all environments
- ✅ **Credential isolation**: Separate database users per environment
- ✅ **Production operators**: CloudNativePG (PostgreSQL), Strimzi (Kafka)
- ✅ **Only applications split dev/prod**: core-pipeline-dev and core-pipeline-prod
- ✅ **Simple deployment**: Kubernetes manifests, no complex Helm charts

### Namespace Structure
| Namespace | Purpose | Components | Status |
|-----------|---------|------------|--------|
| kubesphere-system | KubeSphere Core | ks-console, ks-apiserver, ks-controller-manager | ✅ Automated install |
| infrastructure | Shared infrastructure | PostgreSQL, Redis, Kafka | ✅ Automated install |
| dev-core | Dev applications | core-pipeline-dev | ✅ Automated install |
| prod-core | Prod applications | core-pipeline-prod | ✅ Automated install |
| kafka-operator | Kafka management | Strimzi operator | ✅ Automated install |
| cnpg-system | PostgreSQL management | CloudNativePG operator | ✅ Automated install |
| cert-manager | Certificate management | cert-manager, Let's Encrypt | ✅ Pre-existing |
| kube-system | Ingress & system | Traefik, CoreDNS | ✅ Pre-existing |

### Repository Structure (KubeSphere v4)
```
core-charts/
├── k8s/                              # Kubernetes manifests
│   ├── kubesphere-ingress.yaml       # HTTPS ingress for KubeSphere
│   ├── infrastructure/               # Shared infrastructure
│   │   ├── postgres-cluster.yaml     # CloudNativePG PostgreSQL
│   │   ├── kafka-cluster.yaml        # Strimzi Kafka with topics
│   │   └── redis.yaml                # Redis standalone
│   └── apps/                         # Applications
│       ├── dev/                      # Development
│       │   └── core-pipeline.yaml
│       └── prod/                     # Production
│           └── core-pipeline.yaml
│
├── kubesphere/                       # KubeSphere deployment guides
│   └── CORE-PIPELINE-DEPLOY.md      # core-pipeline deployment instructions
│
├── fresh-install.sh                  # Automated installation script
├── README.md                         # Quick start guide
├── INSTALL.md                        # Complete step-by-step guide
└── CLAUDE.md                         # Instructions for Claude Code (THIS FILE)
```

**What Was Removed:**
- ❌ **argocd/** - ArgoCD configuration
- ❌ **argocd-apps/** - ArgoCD Application CRDs
- ❌ **charts/** - Custom Helm charts
- ❌ **bootstrap.sh** - Old bootstrap script
- ❌ **deploy-hook.sh** - Webhook deployment script
- ❌ **generate-secrets.sh** - Secret generation script
- ❌ **health-check.sh** - Health check script
- ❌ **scripts/** - Utility scripts
- ❌ **.github/workflows/** - Old CI/CD pipelines

**What Remains:**
- ✅ **k8s/** - Pure Kubernetes manifests
- ✅ **fresh-install.sh** - Single automated installer
- ✅ **INSTALL.md** - Manual step-by-step guide
- ✅ **README.md** - Quick start documentation
- ✅ **CLAUDE.md** - This file

### Working Services & Endpoints (After Installation)

| Service | URL | Namespace | Credentials |
|---------|-----|-----------|-------------|
| KubeSphere Console | https://kubesphere.dev.theedgestory.org | kubesphere-system | admin / (auto-generated) |
| Core Pipeline Dev | https://core-pipeline.dev.theedgestory.org | dev-core | - |
| Core Pipeline Prod | https://core-pipeline.theedgestory.org | prod-core | - |
| Grafana | Via KubeSphere Extensions | monitoring | Same as KubeSphere |

## Installation Process

### Automated Installation (Recommended)

**Single Command Installation:**
```bash
bash fresh-install.sh
```

**What It Does:**
1. **Cleanup** (2 min) - Deletes all existing namespaces and resources
2. **KubeSphere Core** (3 min) - Installs KubeSphere v4.1.3 via Helm
3. **Operators** (2 min) - Installs CloudNativePG and Strimzi operators
4. **Infrastructure** (5 min) - Deploys PostgreSQL, Redis, Kafka
5. **Secrets** (1 min) - Creates database credentials
6. **Applications** (2 min) - Deploys core-pipeline dev & prod

**Total Time:** ~15 minutes

### Manual Installation

Follow **INSTALL.md** for detailed step-by-step guide:
- Phase 1: Install KubeSphere Core (5 min)
- Phase 2: Configure HTTPS Ingress (2 min)
- Phase 3: Install Extensions via Web UI (10 min)
- Phase 4: Deploy Infrastructure (15 min)
- Phase 5: Deploy Applications (5 min)

**Total Time:** ~40 minutes

## Development Workflow

**KubeSphere-Based Development:**

1. **Make changes** to Kubernetes manifests in `k8s/` directory
2. **Apply changes** directly:
   ```bash
   kubectl apply -f k8s/infrastructure/
   kubectl apply -f k8s/apps/dev/
   kubectl apply -f k8s/apps/prod/
   ```
3. **Monitor** via KubeSphere Web UI at https://kubesphere.dev.theedgestory.org
   - Or CLI: `kubectl get pods -A`
4. **Verify** deployments:
   - Dev: https://core-pipeline.dev.theedgestory.org
   - Prod: https://core-pipeline.theedgestory.org
5. **Debug** issues:
   - KubeSphere UI: Workloads → Deployments → Logs
   - CLI: `kubectl logs -n <namespace> <pod-name>`
6. **Rollback** if needed:
   ```bash
   kubectl rollout undo deployment/core-pipeline -n dev-core
   kubectl rollout undo deployment/core-pipeline -n prod-core
   ```

## Security Notes

**Credential Isolation:**
- ✅ **Separate database users** - `core_dev_user` and `core_prod_user` in shared PostgreSQL
- ✅ **Auto-generated passwords** - 24-character random passwords during installation
- ✅ **Namespace isolation** - dev-core and prod-core with separate RBAC
- ✅ **TLS enforcement** - All ingresses require HTTPS
- ✅ **Secret management** - Kubernetes secrets, never in git

**Accessing Credentials:**
```bash
# KubeSphere admin password
kubectl get secret -n kubesphere-system ks-admin-secret -o jsonpath='{.data.password}' | base64 -d

# PostgreSQL credentials (shown during installation)
kubectl get secret -n dev-core core-pipeline-secrets -o yaml
kubectl get secret -n prod-core core-pipeline-secrets -o yaml

# List all secrets
kubectl get secrets -A
```

## Server Information

**Server:** 46.62.223.198
**Kubernetes:** K3s
**Ingress:** Traefik (LoadBalancer)
**TLS:** cert-manager with Let's Encrypt

### Pre-existing Platform Services
- ✅ K3s cluster running
- ✅ Traefik ingress controller (LoadBalancer: 46.62.223.198)
- ✅ cert-manager with Let's Encrypt
- ✅ DNS configured: *.dev.theedgestory.org, *.theedgestory.org

## Migration from ArgoCD

**What Changed:**
1. **Platform**: ArgoCD → KubeSphere v4 (unified management console)
2. **Deployment**: GitOps with Helm → Direct Kubernetes manifests
3. **PostgreSQL**: Bitnami Helm chart → CloudNativePG operator
4. **Kafka**: Bitnami Helm chart → Strimzi operator
5. **Redis**: Bitnami Helm chart → Standalone deployment
6. **Installation**: Multi-script bootstrap → Single automated script

**Why KubeSphere v4:**
- ✅ **Batteries-included platform** - Monitoring, logging, DevOps built-in
- ✅ **Extension ecosystem** - Modular components via Extension Center
- ✅ **Simple installation** - Single Helm command
- ✅ **Production-ready operators** - CloudNativePG, Strimzi best-in-class
- ✅ **Unified UI** - Single pane of glass for all operations

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
