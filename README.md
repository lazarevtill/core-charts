# Core Infrastructure - Production Kubernetes Setup

**Status**: 🟢 Production Ready
**TLS Certificates**: ✅ All Valid (Let's Encrypt)
**Last Updated**: October 2025

## 🎯 Overview

Production Kubernetes infrastructure for microservices deployment with monitoring and observability. Deployed on K3s with separate dev/prod environments.

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

1. Go to repository Settings → Webhooks → Add webhook
2. **Payload URL**: `http://46.62.223.198:9000/hooks/deploy-core-charts`
3. **Content type**: `application/json`
4. **Secret**: (matches webhook secret on server)
5. **Events**: Just the push event
6. **Active**: ✅ Enabled

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

## 📊 Server Issues & Fixes Needed

### Critical
- **Node.js webhook-receiver.js deleted but systemd service still references it**
  - Service: `webhook-receiver.service` on port 3001
  - Action needed: Stop and disable the service (we use Go webhook on port 9000)

### Medium Priority
- **infrastructure-db-init job timeouts** - PostgreSQL init job in infrastructure namespace gets stuck
- **core-pipeline-dev repeated failures** - 10+ Helm upgrade timeouts (but pods actually run fine)
- **Two webhook services running** - Port 3001 (broken Node.js) and port 9000 (working Go webhook)

### Low Priority
- **infrastructure ArgoCD app OutOfSync** - Not critical, using per-environment infrastructure instead
- **Untracked files on server** - `node_modules/`, `package-lock.json`, `argocd-investigation.txt`

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
