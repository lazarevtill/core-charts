# CLAUDE.md - AI Assistant Context

**Purpose:** Guide Claude Code when working with this infrastructure repository.

---

## 🚨 CRITICAL RULES

### 1. Documentation Policy
- ✅ **ONLY** update `CLAUDE.md` and `README.md`
- ❌ **NEVER** create additional `.md` files
- **Reason:** Single source of truth, no documentation sprawl

### 2. Secrets Policy
- ✅ Secrets in Kubernetes Secrets only
- ❌ **NEVER** commit secrets to Git
- ✅ Reference secrets in Helm charts via `existingSecret`
- ✅ GitHub push protection will block secret commits

### 3. GitOps Policy
- ✅ All changes via Git commits
- ❌ No manual `kubectl apply` commands (except one-time secret creation)
- ✅ ArgoCD auto-syncs from Git
- ✅ Git is the single source of truth

---

## 🏗️ Architecture Overview

**Type:** GitOps-managed Kubernetes infrastructure on K3s
**Platform:** KubeSphere v4.1.3
**GitOps:** ArgoCD with auto-sync enabled
**Ingress:** nginx-ingress controller (NOT Traefik!)
**Auth:** OAuth2 Proxy with Google SSO

### Key Principles

1. **Pure GitOps:** Git push → ArgoCD auto-sync → Kubernetes deploy
2. **Shared Infrastructure:** One PostgreSQL, one Redis, one Kafka UI for all environments
3. **Credential Isolation:** Separate database users (`core_dev_user`, `core_prod_user`)
4. **Environment Separation:** Only applications split dev/prod, infrastructure is shared
5. **Secrets Never in Git:** Use Kubernetes Secrets, GitHub blocks secret commits
6. **nginx-ingress Only:** All ingresses use `ingressClassName: nginx`

---

## 📁 Repository Structure

```
core-charts/
├── README.md                    # User documentation (how-to guides)
├── CLAUDE.md                    # THIS FILE - AI context
│
├── argocd-apps/                 # ArgoCD Application CRDs
│   ├── infrastructure.yaml      # Shared infra (sync-wave: 1)
│   ├── core-pipeline-dev.yaml   # Dev app (sync-wave: 2)
│   ├── core-pipeline-prod.yaml  # Prod app (sync-wave: 2)
│   └── oauth2-proxy.yaml        # OAuth2 auth (sync-wave: 0)
│
├── charts/
│   ├── infrastructure/          # Helm umbrella chart
│   │   ├── Chart.yaml           # Remote Bitnami dependencies
│   │   ├── values.yaml          # Config (NO secrets!)
│   │   └── templates/           # Kafka UI resources
│   │
│   └── core-pipeline/           # Application Helm chart
│       ├── values.yaml          # Base config
│       ├── values-dev.yaml      # Dev overrides
│       ├── values-prod.yaml     # Prod overrides
│       ├── dev.tag.yaml         # Dev image tag (triggers deploy)
│       ├── prod.tag.yaml        # Prod image tag (triggers deploy)
│       └── templates/           # K8s manifests
│
├── cert-manager/                # TLS certificates
│   └── letsencrypt-issuer.yaml  # Let's Encrypt ClusterIssuer
│
├── oauth2-proxy/                # OAuth2 authentication
│   └── deployment.yaml          # OAuth2 Proxy resources
│
├── setup-oauth2.sh              # Initial OAuth2 setup
└── create-kafka-ui-oauth2-secret.sh  # Kafka UI OAuth2 secret helper
```

---

## 🎯 Common Tasks for Claude

### Task: Deploy New Application Version

**User says:** "Deploy core-pipeline dev version v1.2.3"

**Actions:**
1. Update `charts/core-pipeline/dev.tag.yaml`: `tag: "v1.2.3"`
2. Commit with message: `"deploy: core-pipeline dev v1.2.3"`
3. Push to GitHub
4. ArgoCD auto-syncs within 3 minutes

**DO NOT:**
- Run `kubectl apply` commands
- Modify infrastructure for application deployments
- Create new namespaces manually

---

### Task: Update Infrastructure Configuration

**User says:** "Increase PostgreSQL memory to 1Gi"

**Actions:**
1. Edit `charts/infrastructure/values.yaml`
2. Find `postgresql.primary.resources.limits.memory`
3. Change value to `1Gi`
4. Commit and push
5. ArgoCD auto-syncs

**DO NOT:**
- Edit pod specs directly
- Use `kubectl patch` or `kubectl edit`

---

### Task: Add New Admin Service

**User says:** "Add MinIO console with OAuth2 protection"

**Actions:**
1. Create deployment in `charts/infrastructure/templates/`
2. Add OAuth2 ingress annotations:
   ```yaml
   nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy.oauth2-proxy.svc.cluster.local:4180/oauth2/auth"
   nginx.ingress.kubernetes.io/auth-signin: "https://auth.theedgestory.org/oauth2/start?rd=$scheme://$host$request_uri"
   nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email"
   ```
3. Set `ingressClassName: nginx` (NOT traefik!)
4. Add TLS with `cert-manager.io/cluster-issuer: letsencrypt-prod`
5. Commit and push

**DO NOT:**
- Hardcode secrets in templates
- Use Traefik annotations
- Skip OAuth2 protection for admin services

---

### Task: Troubleshoot Deployment Issue

**User says:** "core-pipeline-dev is not deploying"

**Actions:**
1. Check ArgoCD application status:
   ```bash
   kubectl get application core-pipeline-dev -n argocd
   kubectl describe application core-pipeline-dev -n argocd
   ```
2. Check pod status:
   ```bash
   kubectl get pods -n dev-core
   kubectl describe pod <pod-name> -n dev-core
   ```
3. Check logs:
   ```bash
   kubectl logs <pod-name> -n dev-core
   ```

**Common Issues:**
- Image not found → Check `dev.tag.yaml` tag matches Docker registry
- CrashLoopBackOff → Check application logs
- Pending → Check resource limits vs available node resources
- ArgoCD OutOfSync → Check Git commit vs cluster state

---

## 🔐 Security Architecture

### OAuth2 Multi-Layer Protection

**All admin services protected with Google OAuth2:**

```
User Request
    ↓
Nginx Ingress (TLS termination)
    ↓
OAuth2 Proxy (validates Google login + email whitelist)
    ↓ (sets X-Auth-Request-Email header)
Application (reads email, grants access)
```

**Layer 1 - nginx-ingress:**
- TLS certificate (Let's Encrypt via cert-manager)
- Routes to OAuth2 Proxy for auth check

**Layer 2 - OAuth2 Proxy:**
- Google OAuth2 authentication
- Email whitelist: ONLY `dcversus@gmail.com`
- Sets auth headers for downstream services

**Layer 3 - Applications:**
- **ArgoCD:** Dex authproxy reads `X-Auth-Request-Email` → RBAC grants `role:admin`
- **Kafka UI:** Native OAuth2 + email regex `^dcversus@gmail\.com$`
- **Grafana:** Auth proxy mode with auto-login

**Result:** Unauthorized emails cannot access ANY admin service.

### OAuth2 Configuration Files

**OAuth2 Proxy Deployment:**
- File: `oauth2-proxy/deployment.yaml`
- Google Client ID/Secret: Stored in K8s Secret `oauth2-proxy` (namespace: oauth2-proxy)
- Redirect URI: `https://auth.theedgestory.org/oauth2/callback`
- Cookie domain: `.theedgestory.org` (SSO across all subdomains)

**Kafka UI OAuth2:**
- Client credentials: K8s Secret `kafka-ui-oauth2-secret` (namespace: infrastructure)
- Created by: `create-kafka-ui-oauth2-secret.sh` (reads from oauth2-proxy secret)
- ConfigMap: `charts/infrastructure/templates/kafka-ui-configmap.yaml`
- Ingress: `charts/infrastructure/templates/kafka-ui-ingress.yaml`

---

## 📊 Namespace & Service Map

| Namespace | Services | Purpose |
|-----------|----------|---------|
| `infrastructure` | PostgreSQL, Redis, Kafka UI | Shared infrastructure |
| `dev-core` | core-pipeline-dev | Development application |
| `prod-core` | core-pipeline-prod (2 replicas) | Production application |
| `argocd` | ArgoCD server, controllers | GitOps deployment platform |
| `cert-manager` | cert-manager | TLS certificate automation |
| `oauth2-proxy` | oauth2-proxy (2 replicas) | Google OAuth2 authentication |
| `kube-system` | nginx-ingress, CoreDNS, metrics-server | System services |

### Service Connections

**core-pipeline-dev connects to:**
- PostgreSQL: `infrastructure-postgresql.infrastructure.svc.cluster.local:5432` (database: `core_dev`, user: `core_dev_user`)
- Redis: `infrastructure-redis-master.infrastructure.svc.cluster.local:6379`

**core-pipeline-prod connects to:**
- PostgreSQL: `infrastructure-postgresql.infrastructure.svc.cluster.local:5432` (database: `core_prod`, user: `core_prod_user`)
- Redis: `infrastructure-redis-master.infrastructure.svc.cluster.local:6379`

**Kafka UI connects to:**
- Kafka: `kafka-cluster-kafka-bootstrap.infrastructure.svc.cluster.local:9092`

---

## 🔧 Common Commands Reference

### ArgoCD Operations

```bash
# Get application status
kubectl get applications -n argocd

# Describe specific app
kubectl describe application infrastructure -n argocd

# Manual sync (if auto-sync is slow)
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# Access ArgoCD UI
open https://argo.dev.theedgestory.org
```

### Check Deployments

```bash
# All pods across namespaces
kubectl get pods -A

# Infrastructure namespace
kubectl get pods -n infrastructure

# Application namespaces
kubectl get pods -n dev-core
kubectl get pods -n prod-core

# Check ingresses
kubectl get ingress -A
```

### Debugging

```bash
# Pod logs
kubectl logs -n <namespace> <pod-name> -f

# Pod description (events, status)
kubectl describe pod -n <namespace> <pod-name>

# Check certificates
kubectl get certificates -A
kubectl describe certificate <name> -n <namespace>

# Check secrets
kubectl get secrets -n <namespace>
kubectl describe secret <name> -n <namespace>
```

---

## ⚠️ What NOT to Do

❌ **Never create additional .md files** (only README.md and CLAUDE.md allowed)
❌ **Never commit secrets to Git** (GitHub will block, but don't try)
❌ **Never use Traefik** (infrastructure uses nginx-ingress only)
❌ **Never skip OAuth2 protection** for admin services
❌ **Never use `kubectl apply -f`** for GitOps-managed resources (use Git commits)
❌ **Never create separate infrastructure per environment** (infrastructure is shared)
❌ **Never hardcode passwords/tokens** in Helm charts

---

## ✅ Best Practices

✅ **Always use Git commits** for infrastructure changes
✅ **Always reference secrets** via `existingSecret` in Helm charts
✅ **Always use nginx-ingress** (`ingressClassName: nginx`)
✅ **Always add OAuth2 annotations** to admin service ingresses
✅ **Always use sync-waves** for deployment ordering (ArgoCD)
✅ **Always set resource limits** for new deployments
✅ **Always use TLS** with Let's Encrypt (`cert-manager.io/cluster-issuer: letsencrypt-prod`)

---

## 🐛 Troubleshooting Guide

### Issue: ArgoCD Application OutOfSync

**Diagnosis:**
```bash
kubectl get application <name> -n argocd
kubectl describe application <name> -n argocd | grep -A 20 "Status:"
```

**Causes:**
- Manual `kubectl` changes on cluster (don't do this!)
- Git commit not pulled yet (wait 3 min or manual sync)
- Helm chart syntax errors (check Status.Conditions)

**Fix:**
- If manual changes: Delete resource, let ArgoCD recreate from Git
- If Helm errors: Fix chart syntax in Git, push
- If sync delay: Manual sync via ArgoCD UI or kubectl patch

---

### Issue: Pod CrashLoopBackOff

**Diagnosis:**
```bash
kubectl get pods -n <namespace>
kubectl logs -n <namespace> <pod-name> --previous
kubectl describe pod -n <namespace> <pod-name>
```

**Common Causes:**
- Application error (check logs)
- Missing ConfigMap/Secret (check mounts)
- Wrong database credentials (check secrets)
- Resource limits too low (check resource requests/limits)

---

### Issue: OAuth2 Not Working

**Diagnosis:**
```bash
# Check OAuth2 Proxy
kubectl get pods -n oauth2-proxy
kubectl logs -n oauth2-proxy -l app=oauth2-proxy

# Check ingress annotations
kubectl get ingress <name> -n <namespace> -o yaml | grep -A 5 "annotations:"

# Test without browser cache
curl -I https://<service-url>
```

**Common Causes:**
- OAuth2 Proxy down (check pods)
- Missing ingress annotations (check ingress YAML)
- Wrong redirect URI in Google Console
- Certificate issues (check cert-manager)

**Fix:**
- Ensure ingress has OAuth2 annotations (see "Add New Admin Service" task)
- Check Google Console redirect URIs match
- Verify TLS certificate issued: `kubectl get certificates -A`

---

### Issue: TLS Certificate Not Issuing

**Diagnosis:**
```bash
kubectl get certificates -A
kubectl describe certificate <name> -n <namespace>
kubectl get certificaterequest -A
```

**Common Causes:**
- DNS not pointing to LoadBalancer IP (46.62.223.198)
- Let's Encrypt rate limit (5 per week per domain)
- ClusterIssuer not ready

**Fix:**
- Verify DNS: `dig +short <domain>` should return 46.62.223.198
- Check ClusterIssuer: `kubectl get clusterissuer letsencrypt-prod`
- Wait for cert-manager to retry (automatic)

---

## 📝 Commit Message Conventions

Use conventional commits format:

```bash
# Deployment
deploy: core-pipeline dev v1.2.3

# Configuration change
config: increase PostgreSQL memory to 1Gi

# New feature
feat: add MinIO console with OAuth2 protection

# Bug fix
fix: correct Kafka UI OAuth2 redirect URI

# Infrastructure change
infra: upgrade Redis to 24.0.0

# Security update
security: rotate OAuth2 client secret

# Documentation
docs: update README with new service URLs
```

---

## 🎯 Current Status (October 2025)

### ✅ Fully Deployed

- **GitOps Platform:** ArgoCD with auto-sync
- **Infrastructure:** PostgreSQL 18.0.7, Redis 23.0.10, Kafka UI
- **Applications:** core-pipeline-dev, core-pipeline-prod
- **Authentication:** OAuth2 Proxy with Google SSO
- **TLS:** cert-manager with Let's Encrypt
- **Ingress:** nginx-ingress controller
- **Monitoring:** Prometheus, Grafana

### 🔄 Active

- **Auto-sync:** Enabled on all applications (3min polling)
- **TLS Renewal:** Automatic via cert-manager
- **OAuth2 Session:** Persistent via cookie (domain: .theedgestory.org)

### 📊 Key Metrics

- **Infrastructure Shared:** ✅ One PostgreSQL, Redis for all environments
- **Credential Isolation:** ✅ Separate DB users (core_dev_user, core_prod_user)
- **Security:** ✅ OAuth2 on all admin services, only dcversus@gmail.com allowed
- **GitOps Compliance:** ✅ 100% (no manual kubectl for managed resources)
- **Secrets in Git:** ❌ None (GitHub push protection enforced)

---

## 🚀 Quick Reference Card

**When user wants to:**

| User Request | Action | File to Edit |
|--------------|--------|-------------|
| Deploy new app version | Update tag | `charts/core-pipeline/{dev\|prod}.tag.yaml` |
| Change PostgreSQL config | Edit values | `charts/infrastructure/values.yaml` |
| Change Redis config | Edit values | `charts/infrastructure/values.yaml` |
| Add new admin service | Add templates | `charts/infrastructure/templates/` |
| Update OAuth2 whitelist | Edit ConfigMap | `oauth2-proxy/deployment.yaml` (email list) |
| Check deployment status | ArgoCD UI | https://argo.dev.theedgestory.org |
| View app logs | Grafana or kubectl | https://grafana.dev.theedgestory.org |
| Rollback deployment | Git revert | `git revert <commit-hash>` |

---

**Last Updated:** October 2025
**Infrastructure Version:** v1.0
**ArgoCD:** Auto-sync enabled (3min polling)
**Server:** 46.62.223.198 (K3s cluster)
