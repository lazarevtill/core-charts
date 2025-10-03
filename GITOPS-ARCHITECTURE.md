# GitOps Architecture Analysis & Implementation Plan

## Current State Analysis

### What We Have Now

1. **Webhook-Based Deployment** ✅ WORKING
   - GitHub webhook triggers `deploy-hook.sh` on every push
   - Script deploys infrastructure and applications via Helm
   - Applications are running and healthy
   - Located: `webhook-receiver.js` + `deploy-hook.sh`

2. **ArgoCD Installation** ⚠️ PARTIALLY WORKING
   - ArgoCD is installed and UI accessible
   - Applications created but showing "Unknown" status
   - Cannot pull from GitHub (network timeout)
   - Located: `argocd/applications.yaml`

3. **Gitea Attempt** ❌ IN PROGRESS
   - Trying to set up local Git server as GitHub mirror
   - User/repo creation issues
   - Not fully functional yet

### Core Problem

**ArgoCD cannot connect to GitHub from the cluster**, causing:
- Applications show ComparisonError
- No resource tree visualization
- Cannot sync desired state from Git
- Cannot detect drift

**Error**: `failed to list refs: Get "https://github.com/uz0/core-charts.git/info/refs?service=git-upload-pack": context deadline exceeded`

## Architecture Options

### Option 1: Webhook-Only (Current) - Simple, Working
```
GitHub → Webhook → deploy-hook.sh → Helm → Kubernetes
```

**Pros:**
- ✅ Already working
- ✅ Simple architecture
- ✅ No external dependencies
- ✅ Fast deployments

**Cons:**
- ❌ No GitOps visualization
- ❌ No drift detection
- ❌ No rollback via UI
- ❌ Manual state management

### Option 2: ArgoCD with Local Git Mirror (Gitea) - Complex
```
GitHub → Webhook → deploy-hook.sh → Helm → Kubernetes
              ↓
           Gitea (mirror)
              ↓
          ArgoCD (visualization)
```

**Pros:**
- ✅ GitOps visualization
- ✅ ArgoCD UI for monitoring
- ✅ No external GitHub dependency
- ✅ Drift detection

**Cons:**
- ❌ Complex setup (currently broken)
- ❌ Additional component to maintain (Gitea)
- ❌ Redundant deployment logic
- ❌ Storage overhead

### Option 3: Pure ArgoCD GitOps - Ideal but Not Possible
```
GitHub → ArgoCD → Kubernetes
```

**Pros:**
- ✅ True GitOps
- ✅ Automated sync
- ✅ Drift detection
- ✅ Declarative

**Cons:**
- ❌ **Cannot work**: Cluster has no GitHub access
- ❌ Network timeout issues

### Option 4: Hybrid - ArgoCD Tracking (Recommended)
```
GitHub → Webhook → deploy-hook.sh → Helm → Kubernetes
                                        ↓
                                  ArgoCD (track only)
```

**Pros:**
- ✅ Webhook handles deployment (working)
- ✅ ArgoCD tracks deployed resources
- ✅ Visualization without Git dependency
- ✅ Simple architecture

**Cons:**
- ❌ ArgoCD is "read-only"
- ❌ No automated sync
- ❌ Manual refresh needed

## Recommended Solution: Hybrid Architecture

### Why This Approach?

1. **Webhook system already works** - don't break what works
2. **ArgoCD for visualization only** - use tracking labels
3. **No Gitea complexity** - avoid additional moving parts
4. **GitHub connectivity isn't needed** - if ArgoCD tracks by labels

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Repository                       │
│                   uz0/core-charts (main)                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ push event
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              Webhook Receiver (Server)                       │
│                  webhook-receiver.js                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ triggers
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                 Deploy Hook Script                           │
│                  deploy-hook.sh                              │
│                                                               │
│  1. Pull latest from GitHub                                  │
│  2. Build Helm dependencies                                  │
│  3. Deploy infrastructure (Helm)                             │
│  4. Replicate secrets                                        │
│  5. Deploy applications (Helm)                               │
│  6. Add ArgoCD tracking labels                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ helm install/upgrade
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │Infrastructure│  │  dev-core   │  │  prod-core  │         │
│  │  namespace  │  │  namespace  │  │  namespace  │         │
│  │             │  │             │  │             │         │
│  │ PostgreSQL  │  │ pipeline-dev│  │pipeline-prod│         │
│  │   Redis     │  │             │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         ↑                ↑                 ↑                 │
│         └────────────────┴─────────────────┘                │
│                          │                                   │
│                 ArgoCD tracking labels:                      │
│                 app.kubernetes.io/instance                   │
│                          │                                   │
│         ┌────────────────┴─────────────────┐                │
│         │                                   │                │
│         ↓                                   ↓                │
│  ┌─────────────┐                    ┌─────────────┐         │
│  │   ArgoCD    │                    │  ArgoCD UI  │         │
│  │Application  │◄───────────────────│(Visualization)        │
│  │  Resources  │   reads labels     │             │         │
│  └─────────────┘                    └─────────────┘         │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Clean Up Current Setup (15 min)
1. Remove broken Gitea setup
2. Remove non-functional ArgoCD applications
3. Document current working state

### Phase 2: Configure Resource Tracking (30 min)
1. Update Helm templates to add ArgoCD tracking labels
2. Configure ArgoCD to track resources by label (not Git)
3. Redeploy applications with tracking labels

### Phase 3: Restore ArgoCD Visualization (15 min)
1. Create ArgoCD Applications with label selectors
2. Configure refresh interval
3. Verify resource trees appear

### Phase 4: Testing & Verification (15 min)
1. Trigger webhook deployment
2. Verify ArgoCD shows updated resources
3. Test manual refresh
4. Verify health status display

## Detailed Implementation Steps

### Step 1: Remove Gitea Setup

```bash
# Delete Gitea resources
kubectl delete deployment gitea -n argocd
kubectl delete svc gitea -n argocd
kubectl delete pvc gitea-data -n argocd
kubectl delete configmap gitea-init-script -n argocd
kubectl delete job gitea-init -n argocd
kubectl delete sa gitea-init -n argocd
kubectl delete role gitea-init -n argocd
kubectl delete rolebinding gitea-init -n argocd

# Remove from repository
rm -f argocd/gitea.yaml
rm -f argocd/init-gitea*.yaml
rm -f argocd/init-gitea.sh
rm -f argocd/push-to-gitea.sh
rm -f argocd/sync-to-gitea.sh
```

### Step 2: Add Tracking Labels to Helm Charts

Update `charts/infrastructure/templates/_helpers.tpl`:
```yaml
{{- define "infrastructure.labels" -}}
app.kubernetes.io/name: {{ include "infrastructure.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
# ArgoCD tracking label
argocd.argoproj.io/instance: infrastructure
{{- end }}
```

Update `charts/core-pipeline/templates/_helpers.tpl`:
```yaml
{{- define "core-pipeline.labels" -}}
app.kubernetes.io/name: {{ include "core-pipeline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
# ArgoCD tracking label
argocd.argoproj.io/instance: {{ .Release.Name }}
{{- end }}
```

### Step 3: Create ArgoCD Applications with Label Selectors

Create `argocd/applications-tracking.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd
spec:
  project: infrastructure
  # No source - we track existing resources
  source: null
  destination:
    server: https://kubernetes.default.svc
    namespace: infrastructure
  syncPolicy:
    automated: null  # Manual only - webhook deploys
    syncOptions:
      - CreateNamespace=true
  # Track resources by label selector
  resourceTrackingMethod: label
  resourceInclusionMode: includeExisting
  selector:
    matchLabels:
      argocd.argoproj.io/instance: infrastructure
```

### Step 4: Update Deploy Hook

Update `deploy-hook.sh` to apply tracking labels:
```bash
# After helm install, apply tracking labels
kubectl label --overwrite -n infrastructure \
  deployment,service,configmap,secret \
  argocd.argoproj.io/instance=infrastructure

kubectl label --overwrite -n dev-core \
  deployment,service,configmap,secret \
  argocd.argoproj.io/instance=core-pipeline-dev

kubectl label --overwrite -n prod-core \
  deployment,service,configmap,secret \
  argocd.argoproj.io/instance=core-pipeline-prod
```

## Alternative: Use Kubernetes Dashboard Instead

If ArgoCD proves too complex, consider:

```bash
# Install Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin

# Get token
kubectl -n kubernetes-dashboard create token dashboard-admin

# Access via ingress or port-forward
```

**Pros:**
- Native Kubernetes visualization
- No GitOps complexity
- Works with any deployment method
- Comprehensive resource viewer

**Cons:**
- No GitOps concepts
- No drift detection
- No declarative sync

## Decision Matrix

| Criteria | Webhook Only | Gitea+ArgoCD | ArgoCD Tracking | K8s Dashboard |
|----------|--------------|--------------|-----------------|---------------|
| Complexity | ⭐ Simple | ⭐⭐⭐⭐⭐ Complex | ⭐⭐ Moderate | ⭐⭐ Moderate |
| Visualization | ❌ None | ✅ Full GitOps | ✅ Resource Tree | ✅ Full K8s |
| Drift Detection | ❌ No | ✅ Yes | ⚠️ Limited | ❌ No |
| Maintenance | ✅ Low | ❌ High | ⚠️ Medium | ✅ Low |
| Current State | ✅ Working | ❌ Broken | ⚠️ Needs setup | ⚠️ Not installed |
| GitHub Dependency | ❌ No | ❌ No | ❌ No | ❌ No |

## Recommendation

**Proceed with ArgoCD Tracking (Option 4)** because:
1. ArgoCD already installed
2. Provides visualization without Git complexity
3. Keeps working webhook system
4. No additional components (Gitea)
5. Can be implemented in ~1 hour

If ArgoCD Tracking proves too complex, fall back to **Kubernetes Dashboard** as a simpler visualization tool.

## Next Steps

1. Run investigation script to document current state
2. Get user confirmation on approach (Tracking vs Dashboard)
3. Implement chosen solution step by step
4. Document final architecture
5. Create operational runbooks
