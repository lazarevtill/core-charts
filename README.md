# KubeSphere v4 Platform - Complete Kubernetes Setup

**Platform**: KubeSphere v4.1.3 (LuBan Architecture)
**Kubernetes**: K3s on Ubuntu
**Applications**: core-pipeline (dev + prod)

---

## 🚀 Quick Start

### 1. Install KubeSphere v4

```bash
# On your K3s cluster
helm upgrade --install -n kubesphere-system --create-namespace \
  ks-core https://charts.kubesphere.io/main/ks-core-1.1.4.tgz \
  --debug --wait
```

### 2. Access Web Console

```bash
# Get admin password
kubectl get secret -n kubesphere-system ks-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Access via NodePort (temporary)
kubectl get svc -n kubesphere-system ks-console -o jsonpath='{.spec.ports[0].nodePort}'

# URL: http://YOUR_SERVER_IP:NODEPORT
# Username: admin
# Password: (from command above)
```

### 3. Configure HTTPS Ingress

```bash
kubectl apply -f k8s/kubesphere-ingress.yaml
```

Access: **https://kubesphere.dev.theedgestory.org**

---

## 📦 Architecture

```
KubeSphere v4.1.3 (Microkernel + Extensions)
├── Core Platform
│   ├── Web Console (ks-console)
│   ├── API Server (ks-apiserver)
│   └── Controller Manager (ks-controller-manager)
│
├── Extensions (Install from Extension Center)
│   ├── WhizardTelemetry Monitoring (Prometheus/Grafana)
│   ├── WhizardTelemetry Logging (Vector/OpenSearch)
│   ├── WhizardTelemetry Notification
│   ├── DevOps (Jenkins/Argo CD)
│   ├── Service Mesh (Istio)
│   └── Network & Storage Management
│
└── Custom Applications
    ├── infrastructure/ (PostgreSQL, Kafka, Redis)
    ├── dev-core/ (core-pipeline-dev)
    └── prod-core/ (core-pipeline-prod)
```

---

## 📋 Installation Steps

See [INSTALL.md](./INSTALL.md) for complete step-by-step guide.

**Quick Summary:**

1. ✅ Install KubeSphere v4 Core (~5 min)
2. ✅ Configure HTTPS Ingress (~2 min)
3. ✅ Install Extensions via UI (~10 min)
   - Monitoring
   - Logging
   - DevOps
4. ✅ Deploy Infrastructure (~15 min)
   - PostgreSQL (CloudNativePG)
   - Kafka (Strimzi)
   - Redis (Bitnami)
5. ✅ Deploy Applications (~5 min)
   - core-pipeline-dev
   - core-pipeline-prod

**Total Time**: ~40 minutes

---

## 🎯 What's Included

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Platform** | KubeSphere v4 | Unified management console |
| **Database** | CloudNativePG (PostgreSQL 16) | Application database with HA |
| **Message Queue** | Strimzi (Kafka 3.8) | Event streaming |
| **Cache** | Redis 7.4 | Session & caching |
| **Monitoring** | Prometheus + Grafana | Metrics & dashboards |
| **Logging** | Vector + OpenSearch | Centralized logs |
| **DevOps** | Jenkins / Argo CD | CI/CD pipelines |
| **Applications** | core-pipeline | Your Node.js app (dev + prod) |

---

## 📁 Repository Structure

```
core-charts/
├── README.md                    # This file
├── INSTALL.md                   # Complete installation guide
├── CLAUDE.md                    # AI assistant instructions
│
├── k8s/                         # Kubernetes manifests
│   ├── kubesphere-ingress.yaml      # HTTPS ingress for KubeSphere
│   ├── infrastructure/              # Shared infrastructure
│   │   ├── postgres-cluster.yaml    # CloudNativePG PostgreSQL
│   │   ├── kafka-cluster.yaml       # Strimzi Kafka
│   │   └── redis.yaml               # Redis cache
│   └── apps/                        # Applications
│       ├── dev/                     # Development
│       │   └── core-pipeline.yaml
│       └── prod/                    # Production
│           └── core-pipeline.yaml
│
└── docs/                        # Documentation
    ├── kubesphere-extensions.md # Extension installation guide
    └── troubleshooting.md       # Common issues & fixes
```

---

## 🌐 Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **KubeSphere Console** | https://kubesphere.dev.theedgestory.org | admin / (see install) |
| **Grafana** | Via KubeSphere Extensions | Same as KubeSphere |
| **Core Pipeline Dev** | https://core-pipeline.dev.theedgestory.org | - |
| **Core Pipeline Prod** | https://core-pipeline.theedgestory.org | - |

---

## 🔧 Common Commands

```bash
# Check KubeSphere status
kubectl get pods -n kubesphere-system

# Install extension
kubectl apply -f extensions/monitoring.yaml

# View installed extensions
kubectl get extensions -A

# Deploy app
kubectl apply -f k8s/apps/dev/core-pipeline.yaml

# Check app logs (via CLI)
kubectl logs -n dev-core -l app=core-pipeline

# Or use KubeSphere UI: Workloads → Deployments → core-pipeline → Logs
```

---

## 📖 Documentation

- **[INSTALL.md](./INSTALL.md)** - Complete installation guide
- **[docs/kubesphere-extensions.md](./docs/kubesphere-extensions.md)** - Extension catalog
- **[docs/troubleshooting.md](./docs/troubleshooting.md)** - Common issues
- **Official Docs**: https://kubesphere.io/docs/v4.1/

---

## ⚡ Quick Deploy (After Installation)

```bash
# Clone repo on server
git clone https://github.com/uz0/core-charts.git
cd core-charts

# Deploy everything
kubectl apply -f k8s/kubesphere-ingress.yaml
kubectl apply -f k8s/infrastructure/
kubectl apply -f k8s/apps/dev/
kubectl apply -f k8s/apps/prod/

# Verify
kubectl get pods -A
```

---

## 🆘 Support

- **Issues**: Create GitHub issue
- **Docs**: See `docs/` directory
- **KubeSphere Community**: https://kubesphere.io/community/

---

**Platform Version**: v4.1.3
**Last Updated**: October 2025
**License**: MIT
