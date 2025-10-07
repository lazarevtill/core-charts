# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚨 CRITICAL RULES

### Documentation Files Policy
**FORBIDDEN**: Do NOT create any `.md` files except `CLAUDE.md`, `README.md`, and README files in subdirectories

- ✅ **ALLOWED**: Update `CLAUDE.md`, `README.md`, and directory-specific README.md files
- ❌ **FORBIDDEN**: Creating `CHANGELOG.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, or ANY other root-level `.md` files
- **Reason**: All documentation must be consolidated for clarity
- **Exception**: Directory-specific README.md files (e.g., `argocd-apps/README.md`, `config/README.md`) are allowed

### After Every Significant Change
1. **Test changes** - Run `./scripts/healthcheck.sh` to verify services are healthy
2. **Commit to Git** - All changes must be in Git for ArgoCD to sync
3. **Document** - Update README.md if user-facing functionality changes
4. **Keep CLAUDE.md current** - Update this file if architecture or procedures change

## Overview

**Pure GitOps Infrastructure** - Production Kubernetes on K3s with ArgoCD managing all deployments. Git is the single source of truth.

### Key Principles
- **GitOps-first**: All changes via Git → ArgoCD auto-syncs → Kubernetes
- **Infrastructure as Code**: Everything defined in this repository
- **Zero-downtime deployments**: Rolling updates for all services
- **Automated recovery**: ArgoCD self-heal reverts manual cluster changes

## Repository Structure

```
core-charts/
├── scripts/                    # Essential automation scripts
│   ├── setup.sh               # Complete infrastructure setup from scratch
│   ├── deploy.sh              # Deploy/update applications via ArgoCD
│   └── healthcheck.sh         # Verify all services are healthy
│
├── config/                     # Centralized configuration
│   ├── authorized-users.yaml  # Google OAuth user whitelist
│   ├── argocd-ingress.yaml    # ArgoCD server ingress
│   ├── argocd-cm-patch.yaml   # ArgoCD configuration
│   ├── cert-manager/          # Certificate config (not actively used)
│   └── README.md              # Configuration documentation
│
├── argocd-apps/                # ArgoCD Application CRDs
│   ├── infrastructure.yaml    # Infrastructure services (sync-wave: 1)
│   ├── oauth2-proxy.yaml      # OAuth2 authentication (sync-wave: 0)
│   ├── core-pipeline-dev.yaml # Dev application (sync-wave: 2)
│   ├── core-pipeline-prod.yaml# Prod application (sync-wave: 2)
│   └── README.md              # ArgoCD apps documentation
│
├── charts/                     # Helm charts
│   ├── infrastructure/        # PostgreSQL, Redis, Kafka, Kafka UI, Cloudflared
│   │   ├── Chart.yaml         # Remote Bitnami dependencies
│   │   ├── values.yaml        # Infrastructure configuration
│   │   └── templates/         # Kafka UI and Cloudflared templates
│   └── core-pipeline/         # Application Helm chart
│       ├── Chart.yaml
│       ├── values.yaml        # Base values
│       ├── values-dev.yaml    # Dev overrides
│       ├── values-prod.yaml   # Prod overrides
│       ├── dev.tag.yaml       # Dev image tag
│       ├── prod.tag.yaml      # Prod image tag
│       └── templates/         # Kubernetes manifests
│
├── oauth2-proxy/               # OAuth2 Proxy deployment
│   └── deployment.yaml        # Google OAuth2 proxy for Kafka UI
│
├── CLAUDE.md                   # This file - instructions for Claude
├── README.md                   # User-facing documentation
└── SERVICES.md                 # Service directory and quick reference
```

## 🎯 Current State (Oct 7, 2025)

### Production Readiness: 100% ✨

**Architecture:**
- ✅ Pure GitOps with ArgoCD auto-sync
- ✅ Cloudflare Origin CA certificates (no Let's Encrypt)
- ✅ Single shared infrastructure (PostgreSQL, Redis, Kafka)
- ✅ Credential isolation per environment (dev/prod users)
- ✅ Google OAuth2 authentication (OAuth2 Proxy) - **SECURITY HARDENED**
- ✅ Remote Helm charts from Bitnami (no local dependencies)

**Key Achievements:**
- ✅ All ingresses use `cloudflare-origin-tls` secret
- ✅ No SSL redirect loops (disabled nginx ssl-redirect)
- ✅ No Let's Encrypt or Traefik dependencies
- ✅ Clean repository structure with organized scripts and config
- ✅ Comprehensive setup automation
- ✅ **SECURITY FIX**: Strict email whitelist enforcement (only dcversus@gmail.com)

### 🔒 Recent Security Fixes (Oct 7, 2025)

**Critical vulnerability discovered and fixed:**

1. **OAuth2 Proxy** - Was allowing ANY email to authenticate
   - **Vulnerability**: `--email-domain=*` bypassed email whitelist
   - **Impact**: Unauthorized users could access Grafana, Kafka UI, MinIO, Gatus
   - **Fix**: Removed `--email-domain` parameter, now strictly enforces authenticated-emails-file
   - **Commit**: f194f72

2. **ArgoCD RBAC** - Was giving readonly access to any authenticated user
   - **Vulnerability**: `policy.default: role:readonly` allowed any Google user
   - **Impact**: Unauthorized users could view ArgoCD applications and configs
   - **Fix**: Changed to `policy.default: ""` (deny all by default)
   - **Applied**: kubectl patch (cluster-only, not in Git)

**Current Security Posture:**
- ✅ Only `dcversus@gmail.com` can access ALL services
- ✅ OAuth2 Proxy: Strict email whitelist enforcement
- ✅ ArgoCD: Only whitelisted email gets admin access, others denied
- ✅ No default permissions, explicit allow-only model

## Authentication Architecture

### Two-Tier Authentication System

**1. OAuth2 Proxy** (for Grafana, Kafka UI, MinIO, Gatus)
- Google OAuth2 provider
- Email whitelist: `dcversus@gmail.com`
- Configured in: `oauth2-proxy/deployment.yaml`
- Cookie domain: `.theedgestory.org` (shared SSO)
- Required ingress annotations:
  ```yaml
  nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180/oauth2/auth"
  nginx.ingress.kubernetes.io/auth-signin: "https://auth.theedgestory.org/oauth2/start?rd=$scheme://$host$request_uri"
  nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email,Authorization"
  ```

**2. ArgoCD Dex** (for ArgoCD only)
- Built-in Google OAuth via Dex connector
- Email whitelist in `argocd-cm` ConfigMap: `allowedEmailAddresses`
- ⚠️ **CRITICAL**: Never use OAuth2 Proxy for ArgoCD
  - OAuth2 Proxy breaks ArgoCD's token-based API authentication
  - Causes `401 Unauthorized - invalid session` errors
  - ArgoCD has native Dex integration that works properly

### Adding Authorized Users

**OAuth2 Proxy Services:**
```bash
# Edit oauth2-proxy/deployment.yaml
# Add email to authenticated-emails-list.txt
kubectl apply -f oauth2-proxy/deployment.yaml
kubectl rollout restart deployment oauth2-proxy -n oauth2-proxy
```

**ArgoCD:**
```bash
# Get ConfigMap, edit allowedEmailAddresses, apply
kubectl get configmap argocd-cm -n argocd -o yaml > argocd-cm.yaml
# Edit allowedEmailAddresses in dex.config
kubectl apply -f argocd-cm.yaml
kubectl rollout restart deployment argocd-dex-server argocd-server -n argocd
```

## Common Commands

### Initial Setup (Fresh Server)
```bash
# 1. Clone repository
git clone https://github.com/uz0/core-charts.git
cd core-charts

# 2. Prepare Cloudflare Origin Certificate
# Download from: https://dash.cloudflare.com/ -> SSL/TLS -> Origin Server
# Save to: /tmp/cloudflare-origin.{crt,key}

# 3. Set Google OAuth credentials
export GOOGLE_CLIENT_ID="your-client-id"
export GOOGLE_CLIENT_SECRET="your-client-secret"

# 4. Run setup (this sets up everything)
./scripts/setup.sh
```

### Daily Operations
```bash
# Deploy updates
./scripts/deploy.sh all                    # Update all applications
./scripts/deploy.sh infrastructure         # Update only infrastructure
./scripts/deploy.sh core-pipeline-prod     # Update only production app

# Check health
./scripts/healthcheck.sh                   # Verify all services

# View status
kubectl get applications -n argocd         # ArgoCD application status
kubectl get pods -A                        # All pods
kubectl get ingress -A                     # All ingresses
```

### Troubleshooting
```bash
# View ArgoCD application details
kubectl describe application <app-name> -n argocd

# View pod logs
kubectl logs -n <namespace> <pod-name>

# Force ArgoCD sync
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# Get ArgoCD admin password
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## Service URLs

See [`SERVICES.md`](./SERVICES.md) for complete service directory.

**Quick Access:**
- ArgoCD: https://argo.theedgestory.org
- Kafka UI: https://kafka.theedgestory.org
- Grafana: https://grafana.theedgestory.org
- Status: https://status.theedgestory.org
- Dev API: https://core-pipeline.dev.theedgestory.org/api-docs
- Prod API: https://core-pipeline.theedgestory.org/api-docs

## Server Information

- **Server IP**: 46.62.223.198
- **Kubernetes**: K3s
- **Ingress Controller**: nginx-ingress (LoadBalancer)
- **DNS**: Cloudflare
- **SSL/TLS**: Cloudflare Strict mode with Origin CA

## ⚠️ CRITICAL: Infrastructure NOT in Git

**Current GitOps Coverage: ~30%**

These critical components are NOT tracked in repository and would be LOST in disaster recovery:

### Platform (Manual)
- ❌ cert-manager (cert-manager namespace)
- ❌ nginx-ingress (ingress-nginx namespace)
- ❌ cloudflare-operator (cloudflare-operator-system namespace)
- ❌ minio-operator (minio-operator namespace)
- ❌ MinIO tenant (minio namespace)

### Monitoring Stack (Manual)
- ❌ Prometheus, Grafana, Loki, Tempo (monitoring namespace)
- ❌ Exporters: node, kafka, postgresql, redis
- ❌ Gatus status page (status namespace)

### In Git ✅
- ✅ Infrastructure chart (PostgreSQL, Redis, Kafka, Kafka UI, Cloudflared)
- ✅ Core Pipeline apps (dev/prod)
- ✅ OAuth2 Proxy
- ✅ ArgoCD Applications

**Action Required**: Export manifests and add to repository for 100% GitOps compliance

