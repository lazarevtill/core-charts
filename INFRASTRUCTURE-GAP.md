# Infrastructure Not in Git

⚠️ **CRITICAL**: These components are NOT tracked in Git and would be lost in a disaster recovery scenario.

## Components Installed Manually (Not in Repository)

### Platform Infrastructure

| Component | Namespace | Status | Recovery Command |
|-----------|-----------|--------|------------------|
| **cert-manager** | cert-manager | ❌ Manual | `helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true` |
| **nginx-ingress** | ingress-nginx | ❌ Manual | `helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace` |
| **cloudflare-operator** | cloudflare-operator-system | ❌ Manual | `kubectl apply -f https://github.com/containeroo/cloudflare-operator/releases/latest/download/install.yaml` |
| **minio-operator** | minio-operator | ❌ Manual | Installed via OLM |
| **MinIO Tenant** | minio | ❌ Manual | `kubectl apply -f <minio-tenant.yaml>` (file not in repo) |

### Monitoring Stack

| Component | Namespace | Status | Configuration File |
|-----------|-----------|--------|--------------------|
| **Prometheus** | monitoring | ❌ Manual | Not in repo |
| **Grafana** | monitoring | ❌ Manual | Not in repo |
| **Loki** | monitoring | ❌ Manual | Not in repo |
| **Tempo** | monitoring | ❌ Manual | Not in repo |
| **Promtail** | monitoring | ❌ Manual | Not in repo |
| **Node Exporter** | monitoring | ❌ Manual | Not in repo |
| **Kafka Exporter** | monitoring | ❌ Manual | Not in repo |
| **PostgreSQL Exporter** | monitoring | ❌ Manual | Not in repo |
| **Redis Exporter** | monitoring | ❌ Manual | Not in repo |
| **Deployment Tracker** | monitoring | ❌ Manual | Not in repo |
| **Gatus** | status | ❌ Manual | Not in repo |

### Operators

| Component | Namespace | Status |
|-----------|-----------|--------|
| **OLM (Operator Lifecycle Manager)** | olm | ❌ Manual |
| **Operators** | operators | ❌ Manual |
| **cert-manager operator** | operators | ❌ Manual |
| **kubero-operator** | operators | ❌ Manual |

### Orphaned Resources

| Resource | Namespace | Status | Note |
|----------|-----------|--------|------|
| **landing-page ingress** | default | ⚠️ Orphaned | Application deleted but ingress remains |

## What IS in Git ✅

- ✅ ArgoCD Applications (`argocd-apps/`)
- ✅ Infrastructure chart (PostgreSQL, Redis, Kafka, Kafka UI, Cloudflared)
- ✅ Core Pipeline application (dev/prod)
- ✅ OAuth2 Proxy
- ✅ Configuration files (`config/`)

## Disaster Recovery Risk

**Current State**: If server crashes, you can recover ~30% of infrastructure from Git

**What would be lost**:
- All monitoring and observability
- MinIO storage
- TLS certificate automation (cert-manager)
- Ingress controller
- All operators

## Recommended Actions

### Option 1: Document Manual Steps (Quick)
Create comprehensive bootstrap documentation with exact commands to recreate platform.

### Option 2: Move to GitOps (Proper)
Add all platform components as ArgoCD Applications with Helm charts or manifests in repository.

### Option 3: Hybrid Approach
1. Keep platform (cert-manager, nginx-ingress) as manual prerequisites
2. Move monitoring and MinIO to ArgoCD-managed Helm charts
3. Document prerequisites in README

## Next Steps

1. **Immediate**: Document all kubectl/helm commands used for manual installations
2. **Short-term**: Export current manifests and add to repository
3. **Long-term**: Convert all components to ArgoCD Applications

## How to Export Current Resources

```bash
# Export cert-manager
kubectl get all,ingress,configmap,secret -n cert-manager -o yaml > cert-manager-export.yaml

# Export monitoring
kubectl get all,ingress,configmap,secret -n monitoring -o yaml > monitoring-export.yaml

# Export MinIO
kubectl get all,ingress,configmap,secret,tenant -n minio -o yaml > minio-export.yaml
kubectl get all,ingress,configmap,secret -n minio-operator -o yaml > minio-operator-export.yaml

# Export nginx-ingress
kubectl get all,ingress,configmap,secret -n ingress-nginx -o yaml > nginx-ingress-export.yaml

# Export cloudflare-operator
kubectl get all,ingress,configmap,secret -n cloudflare-operator-system -o yaml > cloudflare-operator-export.yaml
```

---

**Status**: 🔴 Infrastructure is NOT disaster-recovery ready
**Last Updated**: October 7, 2025
