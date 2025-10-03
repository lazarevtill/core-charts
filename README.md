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

### 🚧 Partially Working

- **infrastructure** namespace - Redis running, PostgreSQL init job stuck
- **Redis** - Running in infrastructure namespace but not used by apps

### ❌ Failed/Not Working

- **core-pipeline-dev** - Helm release shows "failed" status (pod is running though)
- **Gitea** - Init job in ImagePullBackOff, not essential
- **Loki** (monitoring namespace) - Helm release failed (loki-stack in same namespace works)

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
# Deploy changes
./deploy-hook.sh

# Connect to a pod
./scripts/connect-pod.sh core-pipeline-dev

# Reveal admin credentials
./scripts/reveal-secrets.sh
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

## 📊 Current Issues

| Issue | Impact | Status |
|-------|--------|--------|
| core-pipeline-dev Helm release marked "failed" | Low - pod is running | 🔍 Investigate |
| infrastructure-db-init job stuck | Medium - blocks shared PostgreSQL | 🚧 In Progress |
| Gitea init job ImagePullBackOff | Low - not essential | ⏸️ Paused |
| Loki (monitoring) failed | Low - loki-stack works | ⏸️ Using loki-stack |

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
