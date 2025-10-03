# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Production Kubernetes infrastructure running on K3s with separate dev/prod environments. Each environment has dedicated PostgreSQL, Kafka, and monitoring stack. Applications deployed via Helm with ArgoCD tracking.

## Common Commands

### Daily Operations
```bash
./setup.sh                          # Bootstrap infrastructure from scratch
./deploy-hook.sh                    # Deploy infrastructure & applications
./health-check.sh                   # Verify HTTPS endpoints
./scripts/connect-pod.sh <name>     # Shell access to a pod
./scripts/reveal-secrets.sh         # Display admin credentials
```

### Kubernetes
```bash
# Check deployment status
kubectl get pods -A
helm list -A

# Check ArgoCD apps
kubectl get applications -n argocd

# View logs
kubectl logs -n <namespace> <pod-name>

# Check ingresses
kubectl get ingress -A
```

### Helm Operations
```bash
# Build chart dependencies (required before deploying infrastructure)
helm dependency build charts/infrastructure/

# Deploy infrastructure
helm upgrade --install infrastructure ./charts/infrastructure --namespace infrastructure --wait

# Deploy application
helm upgrade --install core-pipeline-dev ./charts/core-pipeline \
  --namespace dev-core \
  --values charts/core-pipeline/values-dev.yaml
```

## Architecture

### Current Deployment Model
**Per-Environment Infrastructure** - Each environment (dev/prod) has its own complete infrastructure stack:

```
dev-infra/                          prod-infra/
  ├── PostgreSQL                      ├── PostgreSQL
  ├── Kafka (3 nodes)                 ├── Kafka (3 nodes)
  ├── Prometheus                      ├── Prometheus
  ├── Grafana                         ├── Grafana
  ├── Loki                            ├── Loki
  └── Tempo                           └── Tempo

dev-core/                           prod-core/
  └── core-pipeline-dev               └── core-pipeline-prod (2 replicas)
```

**Additional Centralized Services:**
- `monitoring` namespace - kube-prometheus, loki-stack, tempo-distributed
- `infrastructure` namespace - Shared Redis & PostgreSQL (partially working)
- `argocd` namespace - ArgoCD + Gitea (partial)
- `cert-manager` namespace - TLS certificate management
- `kube-system` - Traefik ingress

### Namespace Structure
| Namespace | Purpose | Status |
|-----------|---------|--------|
| dev-core | Dev applications | ✅ Working |
| prod-core | Prod applications | ✅ Working |
| dev-infra | Dev infrastructure (PostgreSQL, Kafka, monitoring) | ✅ Working |
| prod-infra | Prod infrastructure (PostgreSQL, Kafka, monitoring) | ✅ Working |
| infrastructure | Shared Redis/PostgreSQL (umbrella chart) | 🚧 Partial (Redis OK, PG init stuck) |
| monitoring | Centralized monitoring stack | ✅ Working |
| argocd | GitOps platform | ✅ Working |
| cert-manager | Certificate management | ✅ Working |
| dev-db | Legacy dev postgres | ⚠️ May be unused |
| prod-db | Legacy prod postgres | ⚠️ May be unused |

### Repository Structure
```
core-charts/
├── charts/
│   ├── infrastructure/          # Umbrella chart with subcharts
│   │   ├── postgresql/         # PostgreSQL subchart
│   │   ├── redis/             # Redis subchart
│   │   └── kafka/             # Kafka subchart
│   └── core-pipeline/         # Application chart
│       ├── values.yaml        # Base values
│       ├── values-dev.yaml    # Dev overrides
│       └── values-prod.yaml   # Prod overrides
├── argocd/                    # ArgoCD installation config
│   ├── argocd-ingress.yaml   # Ingress for ArgoCD UI
│   └── projects.yaml         # ArgoCD projects
├── argocd-apps/              # ArgoCD Application CRDs
│   ├── core-pipeline-dev.yaml
│   └── core-pipeline-prod.yaml
├── scripts/
│   ├── connect-pod.sh        # Quick pod shell access
│   └── reveal-secrets.sh     # Show admin credentials
├── setup.sh                  # Bootstrap script
├── deploy-hook.sh           # Main deployment script
└── health-check.sh          # Endpoint health checks
```

### Working Services & Endpoints

| Service | URL | Namespace | Status |
|---------|-----|-----------|--------|
| ArgoCD | https://argo.dev.theedgestory.org | argocd | ✅ |
| Core Pipeline Dev | https://core-pipeline.dev.theedgestory.org/api-docs | dev-core | ✅ |
| Core Pipeline Prod | https://core-pipeline.theedgestory.org/api-docs | prod-core | ✅ |
| Grafana | https://grafana.dev.theedgestory.org | monitoring | ✅ |
| Prometheus | https://prometheus.dev.theedgestory.org | monitoring | ✅ |

### Helm Releases

**Currently Deployed (22 releases):**
- cert-manager (cert-manager)
- traefik, traefik-crd (kube-system)
- infrastructure (infrastructure) - ⚠️ Status: failed
- core-pipeline-dev (dev-core) - ⚠️ Status: failed (but pod running)
- core-pipeline-prod (prod-core) - ✅ Status: deployed
- postgres-dev, kafka-dev, monitoring-dev, grafana-dev, loki-dev, tempo-dev (dev-infra)
- postgres-prod, kafka-prod, monitoring-prod, grafana-prod, loki-prod, tempo-prod (prod-infra)
- kube-prometheus, loki, loki-stack, tempo (monitoring)

### ArgoCD Applications
Only 3 ArgoCD applications currently deployed:
- `core-pipeline-dev` - Synced, Healthy
- `core-pipeline-prod` - Synced, Healthy
- `infrastructure` - OutOfSync, Healthy

**Note:** Most infrastructure is deployed directly via Helm, not managed by ArgoCD.

## Known Issues

| Issue | Impact | Notes |
|-------|--------|-------|
| core-pipeline-dev Helm status "failed" | Low | Pod is running fine, deployment works |
| infrastructure-db-init job stuck | Medium | PostgreSQL in infrastructure namespace can't init |
| Gitea init job ImagePullBackOff | Low | Gitea pod runs, but init job fails |
| Loki (monitoring) Helm failed | Low | loki-stack in same namespace works |
| dev-db/prod-db namespaces | Unknown | May be legacy/unused, check if referenced |

## Important Implementation Details

### Deployment Pattern
This setup uses **per-environment infrastructure** rather than shared services:
- Dev apps connect to dev-infra PostgreSQL/Kafka
- Prod apps connect to prod-infra PostgreSQL/Kafka
- `infrastructure` namespace was intended for shared services but is only partially working

### Helm Chart Dependencies
The infrastructure umbrella chart uses local subcharts:
```yaml
dependencies:
  - name: postgresql-setup
    repository: "file://postgresql"
```
**Always run `helm dependency build charts/infrastructure/` before deploying.**

### Certificate Management
- cert-manager with Let's Encrypt
- Traefik ingress controller
- All HTTP traffic redirects to HTTPS
- Certificates auto-renew

### LoadBalancer
- Traefik LoadBalancer: 46.62.223.198
- External IP assigned by cloud provider
- Handles ports 80, 443

## Current Status Summary

### ✅ Working
- Core applications (dev & prod)
- Per-environment infrastructure (PostgreSQL, Kafka)
- Per-environment monitoring (Prometheus, Grafana, Loki, Tempo)
- ArgoCD UI and application tracking
- TLS certificates
- Ingress routing

### 🚧 In Progress
- infrastructure namespace (Redis works, PostgreSQL init stuck)
- Gitea integration (pod runs, init job fails)

### ❌ Not Working
- infrastructure-db-init job (Terminating/stuck)
- Shared PostgreSQL model (using per-env instead)
- Some monitoring namespace components (loki Helm release failed)

## Development Workflow

1. **Make changes** to charts or configuration
2. **Deploy** via `./deploy-hook.sh` (pulls code, builds deps, deploys Helm)
3. **Verify** with `./health-check.sh` or check ArgoCD UI
4. **Debug** using kubectl logs or `./scripts/connect-pod.sh`

## Security Notes

- Separate namespaces provide dev/prod isolation
- Each environment has dedicated database instances
- TLS enforced on all ingresses
- Admin credentials stored in Kubernetes secrets
- Use `./scripts/reveal-secrets.sh` to view credentials

## Next Steps / TODO

1. Investigate why core-pipeline-dev Helm release shows "failed"
2. Fix or remove infrastructure-db-init job
3. Decide: keep per-env infra OR migrate to shared infrastructure namespace
4. Clean up legacy dev-db/prod-db namespaces if unused
5. Fix or remove Gitea init job
6. Consider consolidating duplicate monitoring stacks
