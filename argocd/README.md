# ArgoCD Visualization with Local Git Server

## Overview

This setup enables ArgoCD UI to visualize deployed applications without requiring external GitHub connectivity. It uses a local Gitea server running inside the cluster.

## Architecture

```
GitHub (push) → Webhook → deploy-hook.sh → Helm deployments
                              ↓
                       sync-to-gitea.sh (background)
                              ↓
                         Gitea (local mirror)
                              ↓
                         ArgoCD (visualization only)
```

- **Gitea**: Local Git server running in `argocd` namespace
- **ArgoCD Applications**: Point to Gitea, not GitHub
- **Webhook**: Triggers Gitea sync in background on each deployment

## Setup Instructions

### 1. Pull Latest Code

```bash
cd /root/core-charts
git pull origin main
```

### 2. Deploy Gitea

```bash
kubectl apply -f argocd/gitea.yaml
kubectl wait --for=condition=ready pod -l app=gitea -n argocd --timeout=300s
```

### 3. Initialize Gitea Repository

```bash
chmod +x argocd/init-gitea.sh
./argocd/init-gitea.sh
```

This runs a Kubernetes Job that:
- Creates an `argocd` admin user
- Creates the `core-charts` repository
- Pushes the current code to Gitea

### 4. Update ArgoCD Applications

```bash
kubectl delete -f argocd/applications.yaml --ignore-not-found
kubectl apply -f argocd/applications.yaml
```

### 5. Force ArgoCD Refresh

```bash
kubectl patch app infrastructure -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
kubectl patch app core-pipeline-dev -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
kubectl patch app core-pipeline-prod -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### 6. Verify ArgoCD UI

Open https://argo.dev.theedgestory.org/applications

You should see:
- `infrastructure` - Infrastructure namespace (PostgreSQL, Redis)
- `core-pipeline-dev` - Dev application
- `core-pipeline-prod` - Prod application

All with resource trees showing deployed pods, services, ingresses, etc.

## How It Works

1. **GitHub Webhook triggers** `deploy-hook.sh`
2. **Script pulls** latest code from GitHub
3. **Script triggers background sync** to Gitea via `sync-to-gitea.sh` (runs in pod)
4. **Script deploys** via Helm (doesn't wait for Gitea sync)
5. **ArgoCD reads** from Gitea to visualize resources

The Gitea sync runs in background and doesn't block deployment. ArgoCD will update within a few seconds once the sync completes.

## Credentials

- **Gitea URL**: http://gitea.argocd.svc.cluster.local:3000
- **Username**: `argocd`
- **Password**: `argocd-password`
- **Repository**: `core-charts`

## Manual Sync to Gitea

If you need to manually sync the repository to Gitea:

```bash
cd /root/core-charts
./argocd/sync-to-gitea.sh
```

This creates a temporary pod that pushes the current GitHub state to Gitea.

## Troubleshooting

### ArgoCD shows "Unknown" status

Check if Gitea is running:
```bash
kubectl get pods -n argocd -l app=gitea
```

Check if repository exists in Gitea:
```bash
kubectl logs -n argocd job/gitea-init
```

### Gitea pod not starting

Check pod status and events:
```bash
kubectl describe pod -n argocd -l app=gitea
```

Check if PVC is bound:
```bash
kubectl get pvc -n argocd gitea-data
```

### Applications not showing resources

Refresh applications manually:
```bash
kubectl patch app infrastructure -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

Check ArgoCD application status:
```bash
kubectl get applications -n argocd
```

View application details:
```bash
kubectl describe application infrastructure -n argocd
```

### Gitea sync failing in webhook

Check if init job completed successfully:
```bash
kubectl get jobs -n argocd gitea-init
kubectl logs -n argocd job/gitea-init
```

Re-run initialization:
```bash
kubectl delete job gitea-init -n argocd --ignore-not-found
./argocd/init-gitea.sh
```

## Files

- **gitea.yaml** - Gitea deployment, service, and PVC
- **init-gitea-job.yaml** - Kubernetes Job to initialize Gitea
- **init-gitea.sh** - Script to trigger initialization Job
- **sync-to-gitea.sh** - Helper script to sync repository to Gitea from inside cluster
- **applications.yaml** - ArgoCD Application resources pointing to Gitea

## Benefits

✅ No external network dependency for ArgoCD  
✅ Webhook continues to handle deployment  
✅ ArgoCD provides visualization only  
✅ All resources visible in ArgoCD UI  
✅ No GitHub connectivity issues  
✅ Background sync doesn't block deployment  
