# ArgoCD Visualization with Local Git Server

## Overview

This setup enables ArgoCD UI to visualize deployed applications without requiring external GitHub connectivity. It uses a local Gitea server running inside the cluster.

## Architecture

```
GitHub (push) → Webhook → deploy-hook.sh → Helm deployments
                              ↓
                         Gitea (local mirror)
                              ↓
                         ArgoCD (visualization only)
```

- **Gitea**: Local Git server running in `argocd` namespace
- **ArgoCD Applications**: Point to Gitea, not GitHub
- **Webhook**: Mirrors code to Gitea on each deployment

## Setup Instructions

### 1. Deploy Gitea

```bash
kubectl apply -f /root/core-charts/argocd/gitea.yaml
```

Wait for Gitea to be ready:
```bash
kubectl wait --for=condition=ready pod -l app=gitea -n argocd --timeout=300s
```

### 2. Initialize Gitea Repository

```bash
/root/core-charts/argocd/init-gitea.sh
```

This will:
- Create an `argocd` admin user
- Create the `core-charts` repository
- Push the current code to Gitea
- Configure git remote for future pushes

### 3. Update ArgoCD Applications

Delete old applications pointing to GitHub:
```bash
kubectl delete -f /root/core-charts/argocd/applications.yaml --ignore-not-found
```

Apply new applications pointing to Gitea:
```bash
kubectl apply -f /root/core-charts/argocd/applications.yaml
```

### 4. Verify ArgoCD UI

Open https://argo.dev.theedgestory.org/applications

You should see:
- `infrastructure` - Infrastructure namespace (PostgreSQL, Redis)
- `core-pipeline-dev` - Dev application
- `core-pipeline-prod` - Prod application

All with status showing deployed resources.

## How It Works

1. **GitHub Webhook triggers** `deploy-hook.sh`
2. **Script pulls** latest code from GitHub
3. **Script mirrors** to local Gitea (step 1.5)
4. **Script deploys** via Helm
5. **ArgoCD reads** from Gitea to visualize resources

## Credentials

- **Gitea URL**: http://gitea.argocd.svc.cluster.local:3000
- **Username**: `argocd`
- **Password**: `argocd-password`
- **Repository**: `core-charts`

## Troubleshooting

**ArgoCD shows "Unknown" status:**
```bash
# Check if Gitea is running
kubectl get pods -n argocd -l app=gitea

# Check if repository exists in Gitea
kubectl exec -n argocd deployment/gitea -- gitea admin repo list
```

**Gitea push fails in deploy-hook.sh:**
```bash
# Re-run initialization
/root/core-charts/argocd/init-gitea.sh
```

**Applications not showing resources:**
```bash
# Refresh applications manually
kubectl patch app infrastructure -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
kubectl patch app core-pipeline-dev -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
kubectl patch app core-pipeline-prod -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## Benefits

✅ No external network dependency for ArgoCD  
✅ Webhook continues to handle deployment  
✅ ArgoCD provides visualization only  
✅ All resources visible in ArgoCD UI  
✅ No GitHub connectivity issues  
