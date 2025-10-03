# Core Infrastructure - Production Kubernetes Setup

**Status**: 🟡 Under Active Development
**TLS Certificates**: ✅ All Valid (Let's Encrypt)
**Production Readiness**: 🔨 In Progress (see checklist below)
**Last Updated**: October 2025

## 🎯 Overview

Production Kubernetes infrastructure for microservices deployment with monitoring and observability. Deployed on K3s with separate dev/prod environments.

## ✅ Production Readiness Checklist

This repository is being transformed into a production-ready, shareable infrastructure template. Track progress below:

### 🔐 Security & Secrets Management
- [x] **Remove all secrets from repository** ✅ CLEAN
  - [x] Audit repository for hardcoded credentials (NONE FOUND)
  - [x] Remove GitHub PAT tokens (only empty placeholders exist)
  - [x] Remove database passwords (only empty placeholders exist)
  - [x] Remove Redis passwords (only empty placeholders exist)
  - [x] Remove API keys (none present)
  - [x] Update .gitignore to prevent future secret commits
- [x] **Implement secure secret injection**
  - [x] Create bootstrap script that accepts secrets via stdin
  - [x] Document required secrets format (YAML schema in secrets.example.yaml)
  - [x] Add secret validation in bootstrap script
  - [x] Provide example secrets template (secrets.example.yaml with comprehensive docs)
- [x] **Per-service credential isolation** ✅ IMPLEMENTED
  - [x] Implement PostgreSQL user generation per service (core_dev_user, core_prod_user)
  - [x] Implement Redis ACL user generation per service (redis_dev_user, redis_prod_user)
  - [x] Auto-generate unique passwords per service (24-32 char random alphanumeric)
  - [x] Document credential isolation architecture in README (See Architecture section)

### 🏗️ Infrastructure & Reliability
- [ ] **Fix HTTP to HTTPS redirects**
  - [x] Configure ingress annotations
  - [ ] Apply Traefik global redirect configuration (requires server access)
  - [ ] Verify all HTTP endpoints redirect to HTTPS with 301
- [ ] **Resolve known infrastructure issues**
  - [ ] Fix PostgreSQL init job timeouts
  - [ ] Fix Helm timeout issues (or document as expected behavior)
  - [ ] Handle concurrent Helm operations gracefully
  - [ ] Close unused firewall port 3001
- [ ] **High availability configuration**
  - [ ] Document autoscaling policies
  - [ ] Configure pod disruption budgets
  - [ ] Set up resource quotas per namespace
  - [ ] Configure network policies for isolation

### 🚀 CI/CD & Automation
- [x] **GitHub Actions pipeline** ✅ 8-PHASE PIPELINE
  - [x] Helm chart linting (helm lint + template rendering)
  - [x] YAML validation (yamllint + kubeval + kubeconform)
  - [x] Secret scanning (TruffleHog + Gitleaks + custom patterns)
  - [x] Dry-run deployments (kind cluster integration tests)
  - [x] Automated testing on PR (full validation suite)
  - [x] Security scanning (Trivy + Kubesec)
  - [x] Bootstrap script validation (syntax + functionality)
  - [x] Documentation checks (completeness + link validation)
- [x] **Deployment automation**
  - [x] Document webhook setup process (See README Webhook section)
  - [ ] Add webhook secret rotation procedure
  - [ ] Implement deployment rollback strategy
  - [ ] Add smoke tests post-deployment

### 📊 Observability & Monitoring
- [ ] **Grafana dashboards**
  - [ ] Add Kubernetes cluster overview dashboard
  - [ ] Add application metrics dashboard
  - [ ] Add database performance dashboard
  - [ ] Add Kafka metrics dashboard
  - [ ] Export dashboards as JSON to repository
- [ ] **Alerting rules**
  - [ ] Define critical alerts (pod crash loops, high error rates)
  - [ ] Define warning alerts (high CPU, memory)
  - [ ] Configure AlertManager routing
  - [ ] Document on-call procedures

### 📖 Documentation & Developer Experience
- [ ] **Comprehensive README**
  - [x] Add production readiness checklist
  - [ ] Document clean machine setup (zero to running)
  - [ ] Add troubleshooting runbook
  - [ ] Document disaster recovery procedures
  - [ ] Add architecture diagrams
- [ ] **Repository organization**
  - [ ] Clean up unused files and scripts
  - [ ] Organize charts into logical directories
  - [ ] Add CHANGELOG.md
  - [ ] Add CONTRIBUTING.md
  - [ ] License file (if open source)

### 🧪 Testing & Validation
- [ ] **Clean machine deployment test**
  - [ ] Provision fresh K3s cluster
  - [ ] Run bootstrap script with test secrets
  - [ ] Verify all services start successfully
  - [ ] Run end-to-end smoke tests
  - [ ] Document deployment time and resource usage
- [ ] **Upgrade testing**
  - [ ] Test helm upgrade path
  - [ ] Test database migration procedures
  - [ ] Test zero-downtime deployments
  - [ ] Document rollback procedures

### 🎯 Production Criteria (Exit Checklist)
- [ ] No secrets in repository ✅
- [ ] Bootstrap script works on clean machine ✅
- [ ] All HTTP endpoints redirect to HTTPS ✅
- [ ] All services have health checks ✅
- [ ] CI/CD pipeline prevents bad deployments ✅
- [ ] Grafana dashboards available ✅
- [ ] Documentation is complete and tested ✅
- [ ] One successful clean machine deployment ✅

**Target Completion**: TBD
**Last Updated**: October 3, 2025

---

## 📋 Current Infrastructure

### ✅ Working Services

**Applications:**
- **core-pipeline-dev** (dev-core namespace) - https://core-pipeline.dev.theedgestory.org/api-docs
- **core-pipeline-prod** (prod-core namespace) - https://core-pipeline.theedgestory.org/api-docs

**Infrastructure (per environment):**
- **PostgreSQL** - dev-infra/prod-infra namespaces
- **Kafka** - 3-node clusters in dev-infra/prod-infra
- **Grafana** - Metrics visualization
- **Prometheus** - Metrics collection
- **Loki** - Log aggregation
- **Tempo** - Distributed tracing
- **AlertManager** - Alert management

**GitOps & Platform:**
- **ArgoCD** - https://argo.dev.theedgestory.org
- **cert-manager** - Automatic TLS certificates
- **Traefik** - Ingress controller with LoadBalancer

### 🚧 Known Issues

- **infrastructure** namespace - Redis running, PostgreSQL init job stuck (timeouts)
- **core-pipeline-dev** - Helm releases fail with timeout but pods run successfully
- **infrastructure ArgoCD app** - Shows OutOfSync (uses per-env infra instead)

## 🔗 Service Endpoints

| Service | URL | Status |
|---------|-----|--------|
| ArgoCD | https://argo.dev.theedgestory.org | ✅ Working |
| Core Pipeline (Dev) | https://core-pipeline.dev.theedgestory.org/api-docs | ✅ Working |
| Core Pipeline (Prod) | https://core-pipeline.theedgestory.org/api-docs | ✅ Working |
| Grafana | https://grafana.dev.theedgestory.org | ✅ Working |
| Prometheus | https://prometheus.dev.theedgestory.org | ✅ Working |

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster (K3s/K3d/EKS)
- kubectl configured
- Helm 3.x
- Git

### Initial Setup
```bash
# Clone repository
git clone https://github.com/uz0/core-charts.git
cd core-charts

# Bootstrap infrastructure (creates namespaces, secrets, deploys charts)
./setup.sh

# Verify health
./health-check.sh
```

### Daily Operations
```bash
# Deploy changes (runs automatically via webhook)
./deploy-hook.sh

# Connect to a pod
./scripts/connect-pod.sh core-pipeline-dev

# Reveal admin credentials
./scripts/reveal-secrets.sh
```

## 🔄 Webhook Automation

### How It Works
This repository uses GitHub webhooks for automatic deployments:

```
GitHub Push → Webhook (port 9000) → deploy-hook.sh → Helm Deploy → Kubernetes
```

**Webhook Endpoint**: `http://46.62.223.198:9000/hooks/deploy-core-charts`

### Webhook Configuration (Server)

The server runs a webhook listener using [webhook](https://github.com/adnanh/webhook):

```bash
# Webhook service status
systemctl status webhook

# Webhook configuration
cat /etc/webhook.conf

# View webhook logs
journalctl -u webhook -f
```

**Configuration** (`/etc/webhook.conf`):
```json
[
  {
    "id": "deploy-core-charts",
    "execute-command": "/root/core-charts/deploy-hook.sh",
    "command-working-directory": "/root/core-charts",
    "trigger-rule": {
      "match": {
        "type": "payload-hash-sha256",
        "secret": "your-secret-key-here",
        "parameter": {
          "source": "header",
          "name": "X-Hub-Signature-256"
        }
      }
    }
  }
]
```

### GitHub Webhook Setup

**Current Status**: ✅ Webhook is configured and working

1. Repository Settings → Webhooks → Add webhook
2. **Payload URL**: `http://46.62.223.198:9000/hooks/deploy-core-charts`
3. **Content type**: `application/json`
4. **Secret**: `your-secret-key-here` (stored in `/etc/webhook.conf`)
5. **Events**: Just the push event
6. **Active**: ✅ Enabled

**Verification on Server:**
```bash
# Check webhook service status
systemctl status webhook

# Monitor webhook activity in real-time
journalctl -u webhook -f

# View webhook config
cat /etc/webhook.conf
```

### What Happens on Push

When you push to `main` branch:

1. **GitHub sends webhook** to server
2. **Webhook service verifies** signature
3. **Runs deploy-hook.sh** which:
   - Pulls latest code (`git pull origin main`)
   - Builds Helm dependencies
   - Deploys infrastructure to `infrastructure` namespace
   - Replicates secrets to app namespaces
   - Deploys `core-pipeline-dev` to `dev-core` namespace
   - Deploys `core-pipeline-prod` to `prod-core` namespace
   - Waits for rollouts to complete

### Testing Webhook

```bash
# On server - trigger deployment manually
bash /root/core-charts/deploy-hook.sh

# Check recent deployments
helm history infrastructure -n infrastructure
helm history core-pipeline-dev -n dev-core
helm history core-pipeline-prod -n prod-core
```

## 🔧 Architecture

### 🔐 Credential Isolation & Security

This infrastructure implements **defense-in-depth** security with per-service credential isolation:

#### PostgreSQL Multi-Tenancy
```
┌─────────────────────────────────────────────────┐
│         PostgreSQL Admin (postgres user)        │
│              Auto-generated password             │
└────────────┬────────────────────────────────────┘
             │
      ┌──────┴──────┐
      │             │
┌─────▼─────┐ ┌────▼──────┐
│  Dev DB   │ │  Prod DB  │
│           │ │           │
│ Database: │ │ Database: │
│  core_dev │ │ core_prod │
│           │ │           │
│ User:     │ │ User:     │
│  core_dev │ │ core_prod │
│  _user    │ │  _user    │
│           │ │           │
│ Password: │ │ Password: │
│  auto-    │ │  auto-    │
│  gen 24ch │ │  gen 24ch │
└───────────┘ └───────────┘
```

**Features:**
- ✅ Separate database per environment
- ✅ Dedicated user per service (no shared credentials)
- ✅ Auto-generated 24-character random passwords
- ✅ Helm post-install job creates users and grants privileges
- ✅ Each user has full access only to their own database
- ✅ Passwords stored as Kubernetes secrets, mounted read-only to apps

#### Redis ACL Isolation
```
┌─────────────────────────────────────────────────┐
│         Redis Admin (default user)              │
│              Auto-generated password             │
└────────────┬────────────────────────────────────┘
             │
      ┌──────┴──────┐
      │             │
┌─────▼─────┐ ┌────▼──────┐
│ Dev ACL   │ │ Prod ACL  │
│           │ │           │
│ User:     │ │ User:     │
│  redis_   │ │  redis_   │
│  dev_user │ │ prod_user │
│           │ │           │
│ Password: │ │ Password: │
│  auto-    │ │  auto-    │
│  gen 32ch │ │  gen 32ch │
│           │ │           │
│ Access:   │ │ Access:   │
│  ~* +@all │ │  ~* +@all │
└───────────┘ └───────────┘
```

**Features:**
- ✅ Separate ACL user per environment
- ✅ Auto-generated 32-character random passwords
- ✅ Helm post-install job creates ACL users
- ✅ Full Redis command access per user (can be restricted)
- ✅ ACL configuration persisted to disk
- ✅ Connection URLs include username for authentication

#### Secret Management Flow
```
1. Helm Install
   ↓
2. Generate Secrets (charts/*/templates/secrets.yaml)
   - randAlphaNum(24-32) generates unique passwords
   - Creates Kubernetes Secret per service
   ↓
3. Init Jobs Run (post-install hook)
   - PostgreSQL: Create users & databases
   - Redis: Create ACL users
   - Read passwords from Kubernetes Secrets
   ↓
4. Application Deployment
   - Secrets mounted as environment variables
   - Apps connect using service-specific credentials
   - No shared passwords between dev/prod
```

**Benefits:**
- 🔒 **Blast Radius Containment**: Compromised dev credentials don't affect prod
- 🔄 **Easy Rotation**: Secrets can be rotated per-environment independently
- 📊 **Audit Trail**: Each environment has distinct database users for logging
- 🚀 **Zero-Config Apps**: Applications receive credentials via environment variables

### Deployment Model
```
┌─────────────────────────────────────────────┐
│          Traefik LoadBalancer               │
│        (46.62.223.198:80,443)              │
│          Let's Encrypt TLS                  │
└──────────────┬──────────────────────────────┘
               │
       ┌───────┼───────┐
       │               │
  ┌────▼────┐    ┌────▼────┐
  │ dev-*   │    │ prod-*  │
  │ envs    │    │ envs    │
  └─────────┘    └─────────┘
```

### Namespace Structure
- **dev-core** - Development applications
- **prod-core** - Production applications
- **dev-infra** - Dev infrastructure (PostgreSQL, Kafka, Grafana, Prometheus, Loki, Tempo)
- **prod-infra** - Prod infrastructure (PostgreSQL, Kafka, Grafana, Prometheus, Loki, Tempo)
- **dev-db** - Legacy dev postgres (may be unused)
- **prod-db** - Legacy prod postgres (may be unused)
- **infrastructure** - Shared Redis & PostgreSQL (partial)
- **monitoring** - Centralized monitoring stack
- **argocd** - GitOps platform
- **cert-manager** - Certificate management

### Helm Releases

**Per-Environment Pattern:**
- `postgres-dev` / `postgres-prod` (dev-infra/prod-infra)
- `kafka-dev` / `kafka-prod` (dev-infra/prod-infra)
- `monitoring-dev` / `monitoring-prod` (Prometheus stack)
- `grafana-dev` / `grafana-prod`
- `loki-dev` / `loki-prod`
- `tempo-dev` / `tempo-prod`

**Application Releases:**
- `core-pipeline-dev` (dev-core)
- `core-pipeline-prod` (prod-core)

**Centralized:**
- `cert-manager` (cert-manager)
- `traefik` (kube-system)
- `kube-prometheus` (monitoring)
- `infrastructure` (infrastructure)

## 🔐 Security

### TLS Certificates
- All endpoints use Let's Encrypt certificates
- cert-manager auto-renewal
- HTTP → HTTPS redirects enforced

### Access Control
- Separate namespaces for dev/prod isolation
- Dedicated PostgreSQL instances per environment
- Dedicated Kafka clusters per environment

## 🐛 Troubleshooting

### Check Pod Status
```bash
kubectl get pods -A | grep -v Running
```

### Check Helm Releases
```bash
helm list -A
```

### View Logs
```bash
kubectl logs -n <namespace> <pod-name>
```

### Check Ingress
```bash
kubectl get ingress -A
```

### Access Admin Credentials
```bash
./scripts/reveal-secrets.sh
```

## 📊 Server Status & Known Issues

### ✅ Fixed
- ~~Duplicate webhook services~~ - Removed broken Node.js service, only Go webhook on port 9000
- ~~Git merge conflicts~~ - Server repo reset to origin/main
- ~~Gitea resources~~ - All cleaned up from cluster

### 🟡 Active Issues

**High Priority:**
- **HTTP to HTTPS redirects not working** - Applications return 404 on HTTP instead of redirecting to HTTPS
  - Root cause: Traefik needs global redirect configuration
  - HTTPS endpoints work correctly
  - Requires server-side Traefik configuration (see Quick Fixes below)

**Medium Priority:**
- **infrastructure-db-init job timeouts** - PostgreSQL init job occasionally gets stuck
- **core-pipeline-dev Helm timeouts** - Helm upgrades timeout but deployments succeed
- **Concurrent Helm operations** - Error: "another operation is in progress" when multiple deployments overlap

**Low Priority:**
- **infrastructure ArgoCD app OutOfSync** - Using per-env infrastructure, not critical
- **Port 3001 still open in firewall** - Should be closed (only need port 9000)

### Quick Fixes

**Configure Traefik global HTTP to HTTPS redirect:**
```bash
# SSH to server
ssh -i ~/.ssh/hetzner root@46.62.223.198

# Check current Traefik configuration
kubectl get deployment traefik -n kube-system -o yaml | grep -A 50 "args:"

# Option 1: Patch Traefik deployment to add redirect
kubectl patch deployment traefik -n kube-system --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--entrypoints.web.http.redirections.entryPoint.to=websecure"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--entrypoints.web.http.redirections.entryPoint.scheme=https"
  }
]'

# Option 2: If Traefik installed via Helm, update values
helm get values traefik -n kube-system > traefik-values.yaml
# Edit traefik-values.yaml to add:
# ports:
#   web:
#     redirectTo:
#       port: websecure
helm upgrade traefik traefik/traefik -n kube-system -f traefik-values.yaml

# Verify redirect is working
curl -I http://core-pipeline.dev.theedgestory.org 2>&1 | grep -E "HTTP|Location"
# Should see: HTTP/1.1 301 Moved Permanently
# Location: https://core-pipeline.dev.theedgestory.org/
```

**Close unused firewall port:**
```bash
ufw delete allow 3001/tcp
```

**Fix stuck Helm operations:**
```bash
# If deployment stuck, check pending releases
helm list --pending -A

# Rollback stuck release
helm rollback <release-name> -n <namespace>
```

## 📚 Repository Structure

```
core-charts/
├── charts/
│   ├── infrastructure/    # Umbrella chart (PostgreSQL, Redis, Kafka)
│   └── core-pipeline/     # Application chart
├── argocd/               # ArgoCD configuration
│   ├── argocd-ingress.yaml
│   └── projects.yaml
├── argocd-apps/          # ArgoCD Application CRDs
│   ├── core-pipeline-dev.yaml
│   └── core-pipeline-prod.yaml
├── scripts/
│   ├── connect-pod.sh
│   └── reveal-secrets.sh
├── setup.sh              # Initial infrastructure bootstrap
├── deploy-hook.sh        # Deployment script
└── health-check.sh       # Endpoint validation
```

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test with `./health-check.sh`
4. Create PR

---

**Maintained by**: TheEdgeStory Team
**Contact**: admin@theedgestory.org
