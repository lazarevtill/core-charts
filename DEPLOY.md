# Pure GitOps Deployment Guide

## Quick Deployment (On Server)

```bash
cd /root/core-charts
git pull origin main
bash fix-argocd-apps.sh
```

This script will:
1. ✅ Delete landing page ArgoCD application (migrated to GitHub Pages)
2. ✅ Clean up old infrastructure raw manifests
3. ✅ Apply updated ArgoCD applications with Helm charts
4. ✅ Trigger ArgoCD sync for all applications

## What Happens Next

ArgoCD will automatically:
1. **Fetch Remote Bitnami Charts** (PostgreSQL 16.4.0, Redis 20.6.0, Kafka 31.0.0)
2. **Deploy Infrastructure** (sync-wave: 1)
   - PostgreSQL with core_dev_user and core_prod_user
   - Redis shared instance
   - Kafka single instance
3. **Deploy Applications** (sync-wave: 2)
   - core-pipeline-dev (connects to core_dev_user)
   - core-pipeline-prod (connects to core_prod_user)

## Monitoring Deployment

### ArgoCD UI
https://argo.dev.theedgestory.org

### CLI
```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Watch infrastructure deployment
kubectl get application infrastructure -n argocd -w

# Check pods
kubectl get pods -n infrastructure
kubectl get pods -n dev-core
kubectl get pods -n prod-core
```

## Expected State

All ArgoCD applications should show:
- **Status:** Synced
- **Health:** Healthy
- **Sync State:** No missing components

Infrastructure should contain:
- PostgreSQL StatefulSet
- Redis Deployment
- Kafka StatefulSet + Zookeeper

## Troubleshooting

### Infrastructure OutOfSync
```bash
kubectl patch application infrastructure -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}'
```

### Missing Secrets
Secrets must exist before applications can start:
```bash
# Check secrets exist
kubectl get secrets -n dev-core | grep -E '(postgres|redis|kafka)'
kubectl get secrets -n prod-core | grep -E '(postgres|redis|kafka)'
```

### ArgoCD Applications Not Updating
```bash
# Force refresh
kubectl patch application infrastructure -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge
```
