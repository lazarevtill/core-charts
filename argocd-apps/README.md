# ArgoCD Applications

This directory contains ArgoCD Application CRDs that define what gets deployed to the cluster.

## Applications

### Infrastructure (`infrastructure.yaml`)
- **Sync Wave**: 1
- **Path**: `charts/infrastructure`
- **Description**: Core infrastructure services (PostgreSQL, Redis, Kafka, Kafka UI, Cloudflare Tunnel)
- **Namespace**: `infrastructure`

### OAuth2 Proxy (`oauth2-proxy.yaml`)
- **Sync Wave**: 0
- **Path**: `oauth2-proxy`
- **Description**: Google OAuth2 authentication proxy for Kafka UI
- **Namespace**: `oauth2-proxy`

### Core Pipeline - Dev (`core-pipeline-dev.yaml`)
- **Sync Wave**: 2
- **Path**: `charts/core-pipeline`
- **Values**: `values-dev.yaml`, `dev.tag.yaml`
- **Description**: Development application instance
- **Namespace**: `dev-core`

### Core Pipeline - Prod (`core-pipeline-prod.yaml`)
- **Sync Wave**: 2
- **Path**: `charts/core-pipeline`
- **Values**: `values-prod.yaml`, `prod.tag.yaml`
- **Description**: Production application instance
- **Namespace**: `prod-core`

## Usage

### Initial Deployment
```bash
# Apply all ArgoCD applications
kubectl apply -f argocd-apps/

# Or use the setup script
./scripts/setup.sh
```

### Updating Applications
```bash
# Update specific application
./scripts/deploy.sh <app-name>

# Update all applications
./scripts/deploy.sh all
```

### Checking Status
```bash
# View all applications
kubectl get applications -n argocd

# View specific application details
kubectl describe application <app-name> -n argocd

# Or use the healthcheck script
./scripts/healthcheck.sh
```

## Sync Waves

Applications are deployed in order using sync-wave annotations:
- **Wave 0**: OAuth2 Proxy (authentication layer)
- **Wave 1**: Infrastructure (databases, message queues)
- **Wave 2**: Applications (core-pipeline services)

## Auto-Sync

All applications have `selfHeal: true` which means:
- Changes in Git are automatically synced to the cluster
- Manual changes in the cluster are reverted to match Git
- Always ensure changes are committed to Git first

## Adding New Applications

1. Create a new YAML file in this directory
2. Set appropriate sync-wave annotation
3. Apply: `kubectl apply -f argocd-apps/<your-app>.yaml`
4. ArgoCD will automatically sync the new application
