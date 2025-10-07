# Service Directory

Quick reference for all infrastructure and application services.

## Platform Services

| Service | URL | Description |
|---------|-----|-------------|
| **ArgoCD** | https://argo.theedgestory.org | GitOps deployment platform - manages all applications |
| **OAuth2 Proxy** | https://auth.theedgestory.org | Google OAuth2 authentication gateway |
| **Gatus** | https://status.theedgestory.org | Service status and health monitoring |

## Infrastructure Services

| Service | URL | Description |
|---------|-----|-------------|
| **Kafka UI** | https://kafka.theedgestory.org | Apache Kafka management and monitoring |
| **Grafana** | https://grafana.theedgestory.org | Metrics visualization and dashboards |
| **MinIO Console** | https://s3-admin.theedgestory.org | S3-compatible object storage admin |

## Applications

| Service | URL | Description |
|---------|-----|-------------|
| **Core Pipeline (Dev)** | https://core-pipeline.dev.theedgestory.org/api-docs | Development environment API |
| **Core Pipeline (Dev Alt)** | https://core-pipeline-dev.theedgestory.org/api-docs | Development environment API (alternate URL) |
| **Core Pipeline (Prod)** | https://core-pipeline.theedgestory.org/api-docs | Production environment API |

## Internal Services

These services are only accessible within the cluster:

| Service | Internal URL | Description |
|---------|--------------|-------------|
| PostgreSQL | `infrastructure-postgresql.infrastructure:5432` | Shared PostgreSQL database |
| Redis | `infrastructure-redis-master.infrastructure:6379` | Shared Redis cache |
| Kafka | `infrastructure-kafka.infrastructure:9092` | Apache Kafka message broker |

## Authentication

Most services are protected by OAuth2 Proxy with Google authentication:
- Only authorized users can access (see `config/authorized-users.yaml`)
- Single Sign-On across all services via `.theedgestory.org` cookie domain
- Currently authorized: `dcversus@gmail.com`

## Getting Credentials

### ArgoCD Admin Password
```bash
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

### Database Credentials
```bash
# Dev
kubectl get secret -n dev-core postgres-core-pipeline-dev-secret -o yaml

# Prod
kubectl get secret -n prod-core postgres-core-pipeline-prod-secret -o yaml
```

### Redis Credentials
```bash
# Dev
kubectl get secret -n dev-core redis-dev-secret -o yaml

# Prod
kubectl get secret -n prod-core redis-prod-secret -o yaml
```

## Quick Actions

### View All Pods
```bash
kubectl get pods -A
```

### View All Ingresses
```bash
kubectl get ingress -A
```

### Check Service Health
```bash
./scripts/healthcheck.sh
```

### Deploy Updates
```bash
# All services
./scripts/deploy.sh all

# Specific service
./scripts/deploy.sh <app-name>
```

## Service Dependencies

```
Platform Layer:
  ├── ArgoCD (manages everything)
  └── OAuth2 Proxy (authenticates users)

Infrastructure Layer:
  ├── PostgreSQL (data storage)
  ├── Redis (caching & queues)
  ├── Kafka (message streaming)
  └── Kafka UI (Kafka management)

Observability Layer:
  ├── Grafana (metrics visualization)
  └── Gatus (status monitoring)

Application Layer:
  ├── Core Pipeline Dev
  └── Core Pipeline Prod
```
