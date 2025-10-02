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

### 🚧 Phase 3: Secret Management (IN PROGRESS)
- [ ] setup.sh - Bootstrap infrastructure from scratch
- [ ] PostgreSQL user/password generation per service
- [ ] Redis user/password generation per service  
- [ ] Automated secret injection on deployment
- [ ] Secret rotation mechanism

### 📋 Phase 4: Database & Access Control
- [ ] PostgreSQL role-based access (prevent cross-app access)
- [ ] Redis ACL configuration (prevent cross-app access)
- [ ] Database schema documentation
- [ ] User-to-service mapping documentation

### 📋 Phase 5: CI/CD Pipeline
- [ ] GitHub Actions workflow for validation
- [ ] Helm chart linting
- [ ] Kubernetes manifest validation
- [ ] Automated testing on PR
- [ ] Manual approval for production
- [ ] GitHub webhook integration

### 📋 Phase 6: GitOps Automation
- [ ] Image tag update automation (core-pipeline)
- [ ] Automated commit on new image push
- [ ] ArgoCD auto-sync configuration
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

## 🔐 Secret Management

### Secret Types
1. **Infrastructure Secrets** - PostgreSQL, Redis, Kafka passwords
2. **Application Secrets** - Per-service database credentials
3. **Admin Secrets** - ArgoCD, Grafana admin passwords
4. **CI/CD Secrets** - GitHub tokens for webhooks

### Access Pattern
```bash
# Each service gets unique credentials
# - core-pipeline-dev: core_user / <generated-password>
# - PostgreSQL admin: postgres / <generated-password>
# - Redis: <generated-password>
```

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
