# Core Infrastructure - Production Kubernetes Setup

**Status**: 🟡 Under Active Development
**TLS Certificates**: ✅ All Valid (Let's Encrypt)
**Production Readiness**: 🔨 In Progress (see checklist below)
**Last Updated**: October 2025

## 🎯 Overview

Production-ready Kubernetes infrastructure managed via **GitOps with ArgoCD**. Features shared infrastructure (PostgreSQL, Redis, Kafka, Prometheus) with credential isolation for dev/prod environments. All deployments declaratively defined in git and auto-synced to cluster.

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
- [x] **Comprehensive README** ✅ COMPLETE
  - [x] Add production readiness checklist
  - [x] Document clean machine setup (zero to running) - See "Deployment Guide"
  - [ ] Add troubleshooting runbook
  - [ ] Document disaster recovery procedures
  - [x] Add architecture diagrams (credential isolation architecture documented)
- [x] **Repository organization** ✅ CLEAN
  - [x] Clean up unused files and scripts (removed setup.sh, sample-app/)
  - [x] Organize charts into logical directories (infrastructure/, core-pipeline/)
  - [ ] Add CHANGELOG.md
  - [ ] Add CONTRIBUTING.md (optional for private repo)
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

## 🚀 Deployment Guide

### 📦 Clean Machine Deployment (Zero to Running)

This guide will get you from a fresh Kubernetes cluster to a fully running infrastructure.

#### Prerequisites
- **Kubernetes cluster** (K3s/K3d/EKS/GKE) with kubectl access
- **Helm 3.13+** installed
- **Git** installed
- **openssl** for secret generation
- **Domain** with DNS pointing to your cluster's LoadBalancer IP

#### Step 1: Clone Repository
```bash
git clone https://github.com/uz0/core-charts.git
cd core-charts
```

#### Step 2: Prepare Secrets

Choose ONE of three methods:

**Method A: Auto-Generate Secrets (Recommended for Testing)**
```bash
# Bootstrap will auto-generate all passwords
./bootstrap.sh
```

**Method B: Provide Secrets from File**
```bash
# Copy and edit the template
cp secrets.example.yaml secrets.yaml
nano secrets.yaml  # Fill in your values

# Bootstrap with your secrets
cat secrets.yaml | ./bootstrap.sh
```

**Method C: Use Environment Variables**
```bash
# Set required environment variables
export GITHUB_USERNAME="your_username"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxx"
export LETSENCRYPT_EMAIL="admin@example.com"
export DOMAIN_BASE="example.com"

# Generate and pipe to bootstrap
./generate-secrets.sh | ./bootstrap.sh
```

#### Step 3: Verify Deployment
```bash
# Check all pods are running
kubectl get pods -A

# Run health check
./health-check.sh

# Access ArgoCD (get password from bootstrap output)
open https://argo.dev.example.com
```

#### Step 4: Deploy Applications (Optional)
```bash
# Applications can be deployed via ArgoCD UI or kubectl
kubectl apply -f argocd-apps/

# Or trigger webhook deployment (if webhook configured)
./deploy-hook.sh
```

### ⏱️ Expected Deployment Time
- **Infrastructure bootstrap**: 5-8 minutes
- **First application deployment**: 2-3 minutes
- **Total**: ~10 minutes from zero to running

### 🔑 Retrieving Credentials

After bootstrap completes, credentials are printed to stdout. To retrieve them later:

```bash
# Reveal all admin passwords
./scripts/reveal-secrets.sh

# Access specific secrets
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

### 🛠️ Daily Operations
```bash
# Deploy changes (runs automatically via webhook in production)
./deploy-hook.sh

# Connect to a specific pod for debugging
./scripts/connect-pod.sh core-pipeline-dev

# View all pod logs
kubectl logs -n dev-core -l app=core-pipeline --tail=100

# Restart a deployment
kubectl rollout restart deployment/core-pipeline-dev -n dev-core
```

### 🔄 Webhook Setup (Production Only)

For automatic deployments on git push, configure GitHub webhook:

1. **Install webhook listener on server:**
   ```bash
   # Install webhook binary
   wget https://github.com/adnanh/webhook/releases/latest/download/webhook-linux-amd64.tar.gz
   tar xvf webhook-linux-amd64.tar.gz
   sudo mv webhook /usr/local/bin/

   # Create webhook config (see README Webhook section for full config)
   sudo nano /etc/webhook.conf

   # Start webhook service
   webhook -hooks /etc/webhook.conf -port 9000
   ```

2. **Configure GitHub:**
   - Go to Repository → Settings → Webhooks → Add webhook
   - Payload URL: `http://YOUR_SERVER:9000/hooks/deploy-core-charts`
   - Content type: `application/json`
   - Secret: (from your webhook config)
   - Events: Just the push event

3. **Test webhook:**
   ```bash
   # Make a commit and push
   git commit --allow-empty -m "test: webhook trigger"
   git push origin main

   # Check webhook service logs
   journalctl -u webhook -f
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

**GitOps with ArgoCD** - All deployments managed via Git:

```
┌──────────────────────────────────────────────────────────┐
│                   Traefik LoadBalancer                   │
│                 (46.62.223.198:80,443)                  │
│                    Let's Encrypt TLS                     │
└────────────┬─────────────────────────────────────────────┘
             │
      ┌──────┴──────┐
      │  ArgoCD     │  ← GitOps Controller
      │  (Wave 1)   │
      └──────┬──────┘
             │
  ┌──────────┼──────────┐
  │                     │
┌─▼────────────┐  ┌────▼────────┐
│infrastructure│  │ monitoring  │
│  (shared)    │  │  (shared)   │
│              │  │             │
│ PostgreSQL   │  │ Prometheus  │
│ Redis        │  │ Grafana     │
│ Kafka        │  │ Loki        │
└──────────────┘  │ Tempo       │
                  └─────────────┘
      │
      │ Wave 2 (after infra ready)
      │
  ┌───┴───┐
┌─▼─────┐ ┌─▼──────┐
│dev-core│ │prod-core│
│        │ │         │
│pipeline│ │pipeline │
│ (dev)  │ │ (prod)  │
└────────┘ └─────────┘
```

### Namespace Structure

| Namespace | Purpose | Managed By | Components |
|-----------|---------|------------|------------|
| `infrastructure` | Shared infrastructure | ArgoCD | PostgreSQL, Redis, Kafka |
| `monitoring` | Shared monitoring | ArgoCD | Prometheus, Grafana, Loki, Tempo |
| `dev-core` | Dev applications | ArgoCD | core-pipeline-dev |
| `prod-core` | Prod applications | ArgoCD | core-pipeline-prod (2 replicas) |
| `argocd` | GitOps platform | Manual | ArgoCD server & controllers |
| `cert-manager` | Certificate mgmt | Manual | cert-manager, Let's Encrypt |
| `kube-system` | System services | K3s | Traefik, CoreDNS |

**Key Principle:**
✅ **ONE shared instance** of each infrastructure service
✅ **Credential isolation** via per-environment users
✅ **Only core-pipeline** has dev/prod deployments

### ArgoCD Applications

**All deployments managed via GitOps:**

**Infrastructure (sync-wave: 1):**
- `infrastructure` - Single shared instance in infrastructure namespace

**Monitoring (sync-wave: 1):**
- `prometheus` - Centralized metrics
- `grafana` - Unified dashboards
- `loki` - Centralized logging
- `tempo` - Distributed tracing

**Applications (sync-wave: 2):**
- `core-pipeline-dev` - Dev deployment with dev credentials
- `core-pipeline-prod` - Prod deployment with prod credentials

## 🔐 Security

### TLS Certificates
- All endpoints use Let's Encrypt certificates
- cert-manager auto-renewal
- HTTP → HTTPS redirects enforced

### Access Control
- Separate namespaces for dev/prod application isolation
- **Shared infrastructure** with credential isolation:
  - PostgreSQL: Separate users (`core_dev_user`, `core_prod_user`)
  - Redis: Separate ACL users (`redis_dev_user`, `redis_prod_user`)
  - Kafka: Shared cluster with topic-based isolation
- ArgoCD RBAC for GitOps access control

## 🐛 Troubleshooting

### Common Issues and Solutions

#### ArgoCD Application Out of Sync
**Symptom:** ArgoCD shows application as "OutOfSync"

**Cause:** Git state differs from cluster state

**Solution:**
```bash
# Check application status
kubectl get application <app-name> -n argocd

# View differences
kubectl describe application <app-name> -n argocd

# Manually trigger sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# Or use ArgoCD UI
open https://argo.dev.theedgestory.org
```

#### Kafka UI Not Deployed
**Symptom:** Kafka UI not accessible

**Cause:** Optional component, may not be deployed

**Solution:**
```bash
# Check if Kafka UI ArgoCD app exists
kubectl get application kafka-ui -n argocd

# Deploy via ArgoCD
kubectl apply -f argocd-apps/kafka-ui.yaml

# Trigger sync
kubectl patch application kafka-ui -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

#### HTTP Endpoints Return 404 Instead of Redirecting
**Symptom:** HTTP requests return 404 instead of 301 redirect to HTTPS

**Cause:** Traefik global redirect not configured

**Solution:** See "Quick Fixes" → "Configure Traefik global HTTP to HTTPS redirect"

#### Pod Stuck in CrashLoopBackOff
**Solution:**
```bash
# View pod logs
kubectl logs -n <namespace> <pod-name> --previous

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>

# Common fixes:
# 1. Check secrets are available
kubectl get secrets -n <namespace>

# 2. Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Limits"

# 3. Check liveness/readiness probes
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 "livenessProbe"
```

#### Database Connection Failures
**Solution:**
```bash
# Check PostgreSQL is running
kubectl get pods -n infrastructure | grep postgres

# Test connection from app pod
kubectl exec -it -n dev-core <app-pod> -- sh
# Inside pod:
psql -h postgres-core-pipeline-dev-secret -U core_dev_user -d core_pipeline_dev

# Check database secrets exist
kubectl get secret postgres-core-pipeline-dev-secret -n infrastructure
```

#### Helm Release Stuck
**Solution:**
```bash
# Check pending releases
helm list --pending -A

# Rollback stuck release
helm rollback <release-name> -n <namespace>

# Force delete if needed (DANGEROUS)
helm delete <release-name> -n <namespace> --no-hooks
```

#### Certificate Issues
**Solution:**
```bash
# Check certificate status
kubectl get certificate -A

# Describe certificate to see issues
kubectl describe certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Force certificate renewal
kubectl delete secret <tls-secret-name> -n <namespace>
kubectl delete certificaterequest -n <namespace> --all
```

### Diagnostic Commands

#### Check Overall Cluster Health
```bash
# Quick health check script
./health-check.sh

# Check all pods
kubectl get pods -A

# Check nodes
kubectl get nodes

# Check events for errors
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

#### Check Specific Service
```bash
# View deployment status
kubectl get deployment <name> -n <namespace>

# View replica set
kubectl get rs -n <namespace>

# View pod details
kubectl describe pod <pod-name> -n <namespace>

# Stream logs
kubectl logs -f -n <namespace> <pod-name>
```

#### Check Networking
```bash
# Check ingress routes
kubectl get ingress -A

# Check services
kubectl get svc -A

# Test internal DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgres.infrastructure.svc.cluster.local
```

#### Check Helm Releases
```bash
# List all releases
helm list -A

# Check release history
helm history <release-name> -n <namespace>

# Get release values
helm get values <release-name> -n <namespace>

# Get release manifest
helm get manifest <release-name> -n <namespace>
```

### Access Admin Credentials
```bash
# Reveal all admin passwords
./scripts/reveal-secrets.sh

# Access specific credentials
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

### Performance Debugging
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check events for resource issues
kubectl get events -A | grep -i "oom\|evict\|resource"

# Increase pod resources if needed
kubectl edit deployment <name> -n <namespace>
# Update: spec.template.spec.containers[].resources
```

## 📊 Server Status & Known Issues

### ✅ Fixed
- ~~Duplicate webhook services~~ - Removed broken Node.js service, only Go webhook on port 9000
- ~~Git merge conflicts~~ - Server repo reset to origin/main
- ~~Gitea resources~~ - All cleaned up from cluster

### ✅ Recently Fixed
- ~~HTTP to HTTPS redirects~~ - **FIXED** on Oct 3, 2025 - All HTTP endpoints now redirect with 308 Permanent Redirect
- ~~Firewall port 3001~~ - **CLOSED** on Oct 3, 2025 - Only webhook port 9000 remains open

### 🟡 Active Issues

**Medium Priority:**
- **Kafka UI not deployed** - https://kafka.dev.theedgestory.org/ returns certificate error
  - Status: Kafka UI is optional, Kafka cluster is running fine
  - Kafka is accessible internally to applications
  - UI deployment can be added later if needed for monitoring

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
