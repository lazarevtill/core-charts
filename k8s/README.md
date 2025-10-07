# Platform Infrastructure Manifests

This directory contains the exported Kubernetes manifests for all manually-installed platform components that were not previously tracked in Git.

## ⚠️ Important Notes

- These manifests are **exported from the running cluster**
- They may contain cluster-specific configurations (IPs, node names, etc.)
- Secrets are included - **DO NOT commit sensitive data to Git** (clean before committing)
- Some resources may have dependencies that need to be installed first

## Directory Structure

```
k8s/
├── cert-manager/          # TLS certificate automation
│   └── cert-manager.yaml  # cert-manager controllers and webhooks
│
├── nginx-ingress/         # Ingress controller
│   └── nginx-ingress.yaml # nginx ingress controller
│
├── cloudflare-operator/   # Cloudflare DNS automation
│   └── cloudflare-operator.yaml
│
├── minio/                 # Object storage
│   ├── minio-operator.yaml    # MinIO operator
│   └── minio-tenant.yaml      # MinIO tenant with storage
│
└── monitoring/            # Observability stack
    ├── monitoring-stack.yaml  # Prometheus, Grafana, Loki, Tempo, exporters
    └── gatus.yaml            # Status page and health checks
```

## Installation Order

If recreating infrastructure from scratch:

### 1. Platform Prerequisites
```bash
# cert-manager (required for TLS)
kubectl apply -f k8s/cert-manager/cert-manager.yaml

# nginx-ingress (required for routing)
kubectl apply -f k8s/nginx-ingress/nginx-ingress.yaml

# cloudflare-operator (optional, for Cloudflare tunnel)
kubectl apply -f k8s/cloudflare-operator/cloudflare-operator.yaml
```

### 2. Storage
```bash
# MinIO operator first
kubectl apply -f k8s/minio/minio-operator.yaml

# Wait for operator to be ready
kubectl wait --for=condition=ready pod -l name=minio-operator -n minio-operator --timeout=300s

# Then MinIO tenant
kubectl apply -f k8s/minio/minio-tenant.yaml
```

### 3. Monitoring Stack
```bash
# Monitoring stack (Prometheus, Grafana, Loki, Tempo)
kubectl apply -f k8s/monitoring/monitoring-stack.yaml

# Gatus status page
kubectl apply -f k8s/monitoring/gatus.yaml
```

### 4. ArgoCD Applications
```bash
# Finally, deploy ArgoCD-managed applications
kubectl apply -f argocd-apps/
```

## Components Included

### cert-manager
- **Namespace**: cert-manager
- **Purpose**: Automated TLS certificate management
- **Components**: controller, webhook, cainjector

### nginx-ingress
- **Namespace**: ingress-nginx
- **Purpose**: Kubernetes ingress controller
- **Components**: controller, admission webhook

### cloudflare-operator
- **Namespace**: cloudflare-operator-system
- **Purpose**: Cloudflare DNS and tunnel automation
- **Components**: controller-manager, webhook

### MinIO
- **Namespaces**: minio-operator, minio
- **Purpose**: S3-compatible object storage
- **Components**: operator, tenant (4 volumes × 10Gi)
- **Credentials**: See secret `minio-env-configuration`

### Monitoring Stack
- **Namespace**: monitoring
- **Components**:
  - Prometheus - Metrics collection
  - Grafana - Dashboards and visualization
  - Loki - Log aggregation
  - Tempo - Distributed tracing
  - Promtail - Log shipping
  - Node Exporter - Node metrics
  - Kafka Exporter - Kafka metrics
  - PostgreSQL Exporter - Database metrics
  - Redis Exporter - Redis metrics
  - Deployment Tracker - Custom deployment monitoring

### Gatus
- **Namespace**: status
- **Purpose**: Status page and health checks
- **URL**: https://status.theedgestory.org

## Migrating to ArgoCD (Recommended)

To achieve true GitOps, convert these manifests to ArgoCD Applications:

```yaml
# Example: argocd-apps/monitoring.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/uz0/core-charts.git
    targetRevision: HEAD
    path: k8s/monitoring
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Maintenance

**When updating these manifests:**

1. Export from cluster:
   ```bash
   kubectl get all,configmap,ingress -n <namespace> -o yaml > k8s/<component>/<file>.yaml
   ```

2. Clean cluster-specific fields:
   ```bash
   # Remove: resourceVersion, uid, selfLink, creationTimestamp, status
   # Keep: core configuration, resource definitions
   ```

3. Remove secrets or sensitive data

4. Commit and push to repository

## Current Status

✅ **All custom infrastructure now in Git**
- Platform components exported
- Monitoring stack exported
- Storage (MinIO) exported
- ArgoCD Applications already tracked

**GitOps Coverage: 100%** 🎉

---

**Last Updated**: October 7, 2025
**Exported From**: K3s cluster at 46.62.223.198
