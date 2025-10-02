# Core Infrastructure - Production Kubernetes Setup

**Status**: 🚧 Production Hardening in Progress  
**TLS Certificates**: ✅ All Valid (Let's Encrypt)  
**Last Updated**: October 2025

## 🎯 Overview

Production-ready Kubernetes infrastructure configuration for microservices deployment, monitoring, and observability. Includes PostgreSQL, Redis, Kafka, ArgoCD, Grafana, Loki, Tempo, and application deployments.

## 📋 Infrastructure Components

### ✅ Shared Infrastructure
- **PostgreSQL** - Primary database (database namespace)
- **Redis** - Caching & queuing (redis namespace)  
- **Kafka** - Event streaming (kafka namespace)
- **Kafka UI** - Kafka management interface

### ✅ Monitoring & Observability
- **Grafana** - Metrics visualization
- **Prometheus** - Metrics collection
- **Loki** - Log aggregation
- **Tempo** - Distributed tracing
- **AlertManager** - Alert management

### ✅ GitOps & Admin
- **ArgoCD** - GitOps deployment (argocd namespace)
- **cert-manager** - Automatic TLS certificate management

### ✅ Applications
- **core-pipeline-dev** - Development environment (dev-core namespace)
- **core-pipeline-prod** - Production environment (prod-core namespace)

## 🔗 Service Endpoints

| Service | URL | Status |
|---------|-----|--------|
| ArgoCD | https://argo.dev.theedgestory.org | ✅ |
| Core Pipeline (Dev) | https://core-pipeline.dev.theedgestory.org/api-docs | ✅ |
| Core Pipeline (Prod) | https://core-pipeline.theedgestory.org/api-docs | ✅ |
| Kafka UI | https://kafka.dev.theedgestory.org | ✅ |
| Grafana | https://grafana.dev.theedgestory.org | ✅ |
| Prometheus | https://prometheus.dev.theedgestory.org | ✅ |

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster (k3s/k3d/EKS)
- kubectl configured
- Helm 3.x
- Git

### Initial Setup
```bash
# Clone repository
git clone https://github.com/uz0/core-charts.git
cd core-charts

# Run setup (creates all secrets, deploys infrastructure)
./setup.sh

# Verify health
./health-check.sh
```

### Daily Operations
```bash
# Deploy changes via webhook
./deploy-hook.sh

# Connect to a pod
./scripts/connect-pod.sh core-pipeline-dev

# Reveal admin credentials
./scripts/reveal-secrets.sh
```

## 📝 Production Readiness Checklist

### ✅ Phase 1: Infrastructure Foundation
- [x] All TLS certificates working (Let's Encrypt)
- [x] cert-manager with host network mode
- [x] Traefik ingress controller operational
- [x] nginx ingress controller removed
- [x] Repository structure cleaned

### ✅ Phase 2: Essential Scripts
- [x] health-check.sh - Endpoint validation
- [x] deploy-hook.sh - GitHub webhook handler
- [x] scripts/connect-pod.sh - Quick pod access
- [x] scripts/reveal-secrets.sh - Admin credential access
- [x] scripts/fix-cert-manager-network.sh - Cert troubleshooting
- [x] scripts/fix-acme-client.sh - ACME client recovery

### ✅ Phase 3: Secret Management
- [x] setup.sh - Bootstrap infrastructure from scratch
- [x] PostgreSQL user/password generation per service
- [x] Redis user/password generation per service  
- [x] Automated secret injection on deployment
- [ ] Secret rotation mechanism

### ✅ Phase 4: Database & Access Control
- [x] PostgreSQL role-based access (prevent cross-app access)
- [x] Redis ACL configuration (prevent cross-app access)
- [x] Database schema documentation
- [x] User-to-service mapping documentation

### ✅ Phase 5: CI/CD Pipeline
- [x] GitHub Actions workflow for validation (.github/workflows/ci.yaml)
- [x] Helm chart linting (.github/workflows/helm-lint.yaml)
- [x] Kubernetes manifest validation
- [x] Automated testing on PR
- [x] Manual approval for production
- [x] GitHub webhook integration (deploy-hook.sh)

### ✅ Phase 6: GitOps Automation
- [x] Image tag update automation (.github/workflows/update-image-tag.yaml)
- [x] Automated commit on new image push
- [x] ArgoCD auto-sync configuration (.github/workflows/sync-argocd.yml)
- [ ] Rollback mechanisms
- [ ] Deployment notifications

### 📋 Phase 7: Monitoring & Persistence
- [ ] Grafana dashboard configurations
- [ ] Persistent volume claims
- [ ] Backup strategies
- [ ] Disaster recovery procedures
- [ ] Log retention policies

### 📋 Phase 8: Security & Compliance
- [ ] Repository secret scanning (git-secrets)
- [ ] RBAC audit
- [ ] Network policies
- [ ] Pod security policies
- [ ] Vulnerability scanning

### 📋 Phase 9: Performance & Scalability
- [ ] Resource limits on all pods
- [ ] Horizontal pod autoscaling
- [ ] Liveness/readiness probes
- [ ] Pod disruption budgets
- [ ] Load testing

### 📋 Phase 10: Documentation & Testing
- [ ] Architecture diagrams
- [ ] Troubleshooting runbook
- [ ] Contribution guidelines
- [ ] Clean machine deployment test
- [ ] Production readiness review

## 🔧 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Traefik Ingress                       │
│                    (Let's Encrypt TLS)                       │
└─────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    ┌────▼─────┐        ┌────▼─────┐        ┌────▼─────┐
    │  ArgoCD  │        │   Apps   │        │Monitor/  │
    │          │        │          │        │  Admin   │
    └────┬─────┘        └────┬─────┘        └────┬─────┘
         │                   │                    │
    ┌────▼──────────────────▼────────────────────▼─────┐
    │           Shared Infrastructure                   │
    │  PostgreSQL │ Redis │ Kafka │ Loki │ Tempo       │
    └───────────────────────────────────────────────────┘
```


## 🔐 Secret Management & Security Isolation

### Database & User Mapping

| Application | PostgreSQL Database | PostgreSQL User | Redis ACL User | Namespace |
|-------------|-------------------|-----------------|----------------|-----------|
| core-pipeline-dev | core_pipeline_dev | core_dev_user | redis_dev_user | dev-core |
| core-pipeline-prod | core_pipeline_prod | core_prod_user | redis_prod_user | prod-core |
| Admin/Infrastructure | postgres | postgres | default | database/redis |

### Security Isolation Model

**PostgreSQL Isolation:**
- Each application has a **dedicated database** with a **unique user**
- `core_dev_user` can ONLY access `core_pipeline_dev` database
- `core_prod_user` can ONLY access `core_pipeline_prod` database  
- Cross-application access is prevented at the PostgreSQL user permission level
- Passwords are auto-generated (32 characters) and unique per user

**Redis Isolation:**
- Redis ACL configured with separate users per environment
- `redis_dev_user` - dedicated ACL user for dev applications
- `redis_prod_user` - dedicated ACL user for prod applications
- Each user has unique auto-generated password (32 characters)
- ACL rules prevent cross-environment access

**Secret Replication:**
- Secrets are replicated to application namespaces with strict isolation:
  - `dev-core` namespace: receives ONLY dev secrets (postgres-core-pipeline-dev-secret, redis-dev-secret)
  - `prod-core` namespace: receives ONLY prod secrets (postgres-core-pipeline-prod-secret, redis-prod-secret)
- Secret replicator job ensures proper namespace isolation

### Secret Types & Storage

1. **Infrastructure Admin Secrets** (database/redis namespaces)
   - PostgreSQL: `postgresql` secret (admin password)
   - Redis: `redis` secret (admin password)

2. **Application Database Secrets** (database namespace)
   - `postgres-core-pipeline-dev-secret` (DB_USERNAME, DB_PASSWORD, DB_HOST, DB_PORT, DB_DATABASE)
   - `postgres-core-pipeline-prod-secret` (DB_USERNAME, DB_PASSWORD, DB_HOST, DB_PORT, DB_DATABASE)

3. **Application Redis Secrets** (redis namespace)  
   - `redis-dev-secret` (REDIS_USERNAME, REDIS_PASSWORD, REDIS_HOST, REDIS_PORT, REDIS_URL)
   - `redis-prod-secret` (REDIS_USERNAME, REDIS_PASSWORD, REDIS_HOST, REDIS_PORT, REDIS_URL)

4. **Replicated Application Secrets** (dev-core/prod-core namespaces)
   - Auto-replicated from source namespaces via secret-replicator job
   - Applications consume secrets from their own namespace only

### Access Credentials

```bash
# View PostgreSQL dev credentials
kubectl -n database get secret postgres-core-pipeline-dev-secret -o yaml

# View PostgreSQL prod credentials  
kubectl -n database get secret postgres-core-pipeline-prod-secret -o yaml

# View Redis dev credentials
kubectl -n redis get secret redis-dev-secret -o yaml

# View Redis prod credentials
kubectl -n redis get secret redis-prod-secret -o yaml

# Admin access (superuser only)
./scripts/reveal-secrets.sh
```

### How It Works

1. **Setup Phase** (`setup.sh`):
   - Generates admin passwords for PostgreSQL and Redis
   - Creates infrastructure namespaces
   - Deploys Helm charts which auto-generate application-specific secrets

2. **Initialization Phase** (Helm hooks):
   - PostgreSQL init job creates databases and users with generated passwords
   - Redis ACL init job creates ACL users with generated passwords
   - Secret replicator copies appropriate secrets to application namespaces

3. **Runtime Phase**:
   - Applications read secrets from their namespace (dev-core or prod-core)
   - Each app can only access its designated database/Redis instance
   - Cross-environment access is prevented by ACLs and user permissions
## 🐛 Troubleshooting

### Certificate Issues
```bash
# Check certificate status
kubectl get certificate -A

# Fix cert-manager network access
./scripts/fix-cert-manager-network.sh
```

### Pod Crashes
```bash
# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Check credentials
./scripts/reveal-secrets.sh
```

### Database Connection Issues
```bash
# Verify PostgreSQL
kubectl exec -n database postgresql-0 -- psql -U postgres -c '\du'

# Verify Redis
kubectl exec -n redis redis-master-0 -- redis-cli ping
```

## 🎯 Known Issues & Solutions

| Issue | Impact | Solution | Status |
|-------|--------|----------|--------|
| Swagger path was /api-docs not /swagger | Documentation | Updated health-check.sh | ✅ Fixed |
| cert-manager blocked by kube-router | TLS cert issuance | Host network mode | ✅ Fixed |
| Dual ingress controllers (nginx + traefik) | Traffic routing | Removed nginx | ✅ Fixed |
| Credential mismatch in new pods | Pod crashes | Secret management needed | 🚧 In Progress |

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Production Readiness Roadmap](./PRODUCTION_READINESS.md)

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run validation: `./health-check.sh`
4. Create PR
5. Automated checks will run
6. Manual approval for production changes

## 📄 License

[Your License Here]

---

**Maintained by**: TheEdgeStory Team  
**Contact**: admin@theedgestory.org
# Test webhook deployment
