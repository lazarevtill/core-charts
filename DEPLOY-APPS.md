# Deploy Missing ArgoCD Applications

## Problem
The following applications are not showing in ArgoCD UI:
- Kafka UI
- Grafana
- Loki Stack
- Tempo
- Cert Manager

## Solution
All application definitions exist in `argocd-apps/` directory but haven't been applied to the cluster yet.

### Deploy All Applications

```bash
./scripts/deploy-argocd-apps.sh
```

This will apply all applications from `argocd-apps/`:
- `kafka-ui.yaml` - Kafka management UI
- `grafana.yaml` - Metrics & logs visualization
- `loki-stack.yaml` - Log aggregation
- `tempo.yaml` - Distributed tracing
- `cert-manager.yaml` - TLS certificate management
- `postgresql.yaml`, `redis.yaml`, `kafka.yaml` - Individual data services

### Manual Deployment

Or apply individually:
```bash
kubectl apply -f argocd-apps/kafka-ui.yaml
kubectl apply -f argocd-apps/grafana.yaml
kubectl apply -f argocd-apps/loki-stack.yaml
kubectl apply -f argocd-apps/tempo.yaml
kubectl apply -f argocd-apps/cert-manager.yaml
```

### Verify
Check ArgoCD UI at https://argocd.dev.theedgestory.org or:
```bash
kubectl get applications -n argocd
```

## PostgreSQL Init Job Issue

The `infrastructure-db-init` job is stuck waiting for PostgreSQL. Debug with:
```bash
./scripts/debug-postgres-init.sh
```

Common causes:
1. PostgreSQL pod not running
2. PostgreSQL service not ready
3. NetworkPolicy blocking connection
4. Wrong namespace (should be `infrastructure`)
