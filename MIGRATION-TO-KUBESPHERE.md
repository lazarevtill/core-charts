# Migration to KubeSphere Platform

**Goal**: Migrate from custom ArgoCD setup to KubeSphere complete platform with all components managed centrally.

**Timeline**: 2-4 hours
**Downtime**: Minimal (rolling migration)

---

## Phase 1: Pre-Migration Checklist ✅

**On your server, verify current state:**

```bash
# 1. Check current cluster status
kubectl get nodes
kubectl get pods -A

# 2. Backup current configurations
kubectl get all -A -o yaml > /root/backup-before-kubesphere.yaml
kubectl get ingress -A -o yaml > /root/backup-ingresses.yaml

# 3. Export current secrets (important!)
kubectl get secret -n infrastructure -o yaml > /root/backup-secrets-infrastructure.yaml
kubectl get secret -n dev-core -o yaml > /root/backup-secrets-dev.yaml
kubectl get secret -n prod-core -o yaml > /root/backup-secrets-prod.yaml

# 4. Check storage class (required for KubeSphere)
kubectl get storageclass
# Should show: local-path (default)
```

**Expected output**: All pods running, secrets backed up, storage class exists.

---

## Phase 2: Install KubeSphere (15 minutes) 🚀

**Install KubeSphere on your existing K3s cluster:**

```bash
# 1. Download KubeSphere installer
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/kubesphere-installer.yaml

# 2. Download cluster configuration
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/cluster-configuration.yaml

# 3. Watch installation progress (takes ~10 minutes)
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f

# 4. Wait for completion message:
# "Welcome to KubeSphere!"
# Console: http://46.62.223.198:30880
# Account: admin
# Password: P@88w0rd
```

**Verify installation:**

```bash
# Check all KubeSphere pods are running
kubectl get pods -n kubesphere-system

# Should see ~15 pods all Running
```

---

## Phase 3: Configure KubeSphere Ingress (10 minutes) 🌐

**Create Traefik ingress for KubeSphere console:**

```bash
cat > /tmp/kubesphere-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubesphere-console
  namespace: kubesphere-system
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - kubesphere.dev.theedgestory.org
      secretName: kubesphere-tls
  rules:
    - host: kubesphere.dev.theedgestory.org
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ks-console
                port:
                  number: 80
EOF

kubectl apply -f /tmp/kubesphere-ingress.yaml
```

**Access KubeSphere UI:**

```bash
# Open in browser: https://kubesphere.dev.theedgestory.org
# Login: admin / P@88w0rd
# IMPORTANT: Change password immediately!
```

---

## Phase 4: Enable KubeSphere Components (20 minutes) 📦

**Enable pluggable components via KubeSphere ConfigMap:**

```bash
# Edit KubeSphere configuration
kubectl edit cm ks-installer -n kubesphere-system
```

**Change these values from `false` to `true`:**

```yaml
  ks-installer.yaml: |
    # ... existing config ...

    # Enable DevOps (Jenkins CI/CD)
    devops:
      enabled: true

    # Enable monitoring (Prometheus/Grafana - enhanced)
    monitoring:
      storageClass: local-path
      prometheusReplicas: 1
      prometheusMemoryRequest: 400Mi

    # Enable logging (Elasticsearch/FluentBit)
    logging:
      enabled: true
      logsidecar:
        enabled: true
        replicas: 2

    # Enable alerting
    alerting:
      enabled: true

    # Enable auditing
    auditing:
      enabled: true

    # Enable events
    events:
      enabled: true

    # Enable service mesh (optional - for advanced traffic management)
    servicemesh:
      enabled: false  # Can enable later if needed

    # Enable network policy
    network:
      networkpolicy:
        enabled: true
```

**Wait for components to install:**

```bash
# Watch installation progress
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f

# Check component pods
kubectl get pods -n kubesphere-devops-system
kubectl get pods -n kubesphere-logging-system
kubectl get pods -n kubesphere-monitoring-system
```

---

## Phase 5: Install Strimzi Kafka Operator (15 minutes) ☕

**Install via Helm (KubeSphere compatible):**

```bash
# 1. Add Strimzi Helm repo
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# 2. Create namespace
kubectl create namespace kafka-operator

# 3. Install Strimzi operator
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka-operator \
  --set watchNamespaces="{infrastructure}" \
  --wait

# 4. Verify operator is running
kubectl get pods -n kafka-operator
```

**Deploy Kafka cluster (managed by Strimzi):**

```bash
cat > /tmp/kafka-cluster.yaml << 'EOF'
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: infrastructure-kafka
  namespace: infrastructure
spec:
  kafka:
    version: 3.8.0
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
      inter.broker.protocol.version: "3.8"
    storage:
      type: ephemeral
    resources:
      requests:
        memory: 512Mi
        cpu: 250m
      limits:
        memory: 1Gi
        cpu: 500m
  zookeeper:
    replicas: 3
    storage:
      type: ephemeral
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 250m
  entityOperator:
    topicOperator: {}
    userOperator: {}
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: core-pipeline-events
  namespace: infrastructure
  labels:
    strimzi.io/cluster: infrastructure-kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 604800000  # 7 days
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: core-pipeline-commands
  namespace: infrastructure
  labels:
    strimzi.io/cluster: infrastructure-kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 604800000
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: core-pipeline-logs
  namespace: infrastructure
  labels:
    strimzi.io/cluster: infrastructure-kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 259200000  # 3 days
EOF

kubectl apply -f /tmp/kafka-cluster.yaml

# Wait for Kafka cluster to be ready
kubectl wait kafka/infrastructure-kafka --for=condition=Ready --timeout=300s -n infrastructure
```

---

## Phase 6: Install CloudNativePG PostgreSQL Operator (15 minutes) 🐘

**Install CloudNativePG operator:**

```bash
# 1. Install operator
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml

# 2. Verify operator is running
kubectl get pods -n cnpg-system

# 3. Create PostgreSQL cluster (replaces Bitnami PostgreSQL)
cat > /tmp/postgresql-cluster.yaml << 'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: infrastructure-postgres
  namespace: infrastructure
spec:
  instances: 1
  primaryUpdateStrategy: unsupervised

  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"

  bootstrap:
    initdb:
      database: postgres
      owner: postgres
      postInitSQL:
        - CREATE DATABASE core_pipeline_dev;
        - CREATE USER core_dev_user WITH PASSWORD 'CHANGE_ME_DEV_PASSWORD';
        - GRANT ALL PRIVILEGES ON DATABASE core_pipeline_dev TO core_dev_user;
        - CREATE DATABASE core_pipeline_prod;
        - CREATE USER core_prod_user WITH PASSWORD 'CHANGE_ME_PROD_PASSWORD';
        - GRANT ALL PRIVILEGES ON DATABASE core_pipeline_prod TO core_prod_user;

  storage:
    size: 10Gi
    storageClass: local-path

  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"

  monitoring:
    enabled: true
    podMonitorEnabled: true
EOF

kubectl apply -f /tmp/postgresql-cluster.yaml

# Wait for cluster to be ready
kubectl wait cluster/infrastructure-postgres --for=jsonpath='{.status.phase}'=Cluster in healthy state --timeout=300s -n infrastructure
```

---

## Phase 7: Migrate Existing Applications (30 minutes) 🔄

**Update core-pipeline deployments to use new infrastructure:**

### 7.1 Update PostgreSQL Connection Strings

```bash
# Get new PostgreSQL service name
kubectl get svc -n infrastructure | grep postgres

# Expected: infrastructure-postgres-rw (read-write service)
# Connection string: infrastructure-postgres-rw.infrastructure.svc.cluster.local:5432
```

### 7.2 Update Kafka Bootstrap Servers

```bash
# Get Kafka bootstrap service
kubectl get svc -n infrastructure | grep kafka

# Expected: infrastructure-kafka-kafka-bootstrap
# Bootstrap servers: infrastructure-kafka-kafka-bootstrap.infrastructure.svc.cluster.local:9092
```

### 7.3 Create KubeSphere Projects (Namespaces)

**Via KubeSphere UI:**
1. Login to https://kubesphere.dev.theedgestory.org
2. Go to **Workspaces** → Create Workspace: `core-pipeline`
3. In workspace, create **Projects**:
   - `dev-core` (for development)
   - `prod-core` (for production)

**Or via CLI:**

```bash
# Projects already exist, just add KubeSphere labels
kubectl label namespace dev-core kubesphere.io/workspace=core-pipeline
kubectl label namespace prod-core kubesphere.io/workspace=core-pipeline
```

---

## Phase 8: Deploy Core-Pipeline Applications (20 minutes) 🚢

**Update application manifests in core-charts repo (I'll provide files)**

**Then deploy via KubeSphere:**

1. **Via UI:**
   - Workspaces → core-pipeline → dev-core → Application Workloads → Deploy New Application
   - Use **Git** deployment method
   - Point to: https://github.com/uz0/core-pipeline

2. **Via CLI** (traditional kubectl):

```bash
# Deploy dev
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/k8s/core-pipeline-dev.yaml

# Deploy prod
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/k8s/core-pipeline-prod.yaml

# Check deployments
kubectl get pods -n dev-core
kubectl get pods -n prod-core
```

---

## Phase 9: Configure Monitoring & Dashboards (15 minutes) 📊

**Access Grafana via KubeSphere:**

```bash
# Get Grafana URL from KubeSphere
# Navigate to: Platform → Monitoring → Custom Monitoring

# Or access directly via NodePort:
kubectl get svc -n kubesphere-monitoring-system grafana

# Import Kafka dashboard
# Dashboard ID: 10667 (Strimzi Kafka)
# Dashboard ID: 12485 (PostgreSQL CloudNativePG)
```

---

## Phase 10: Update DNS & Ingresses (10 minutes) 🌍

**Update ingresses for new setup:**

```bash
# Verify all ingresses are working
kubectl get ingress -A

# Expected ingresses:
# - kubesphere.dev.theedgestory.org (KubeSphere UI)
# - core-pipeline.dev.theedgestory.org (Dev app)
# - core-pipeline.theedgestory.org (Prod app)
# - grafana.dev.theedgestory.org (Grafana)
# - prometheus.dev.theedgestory.org (Prometheus)
```

---

## Phase 11: Cleanup Old Components (15 minutes) 🧹

**Remove old ArgoCD and Bitnami charts:**

```bash
# 1. Delete old ArgoCD applications
kubectl delete application --all -n argocd

# 2. Delete old ArgoCD (optional - can keep for GitOps)
# kubectl delete namespace argocd

# 3. Delete old Bitnami deployments (already done)
# Kafka, PostgreSQL, Redis from Bitnami charts removed

# 4. Cleanup old custom resources
kubectl delete crd $(kubectl get crd | grep bitnami | awk '{print $1}')

# 5. Verify cleanup
kubectl get pods -A | grep -E 'argocd|bitnami'
# Should return nothing or only ArgoCD if you kept it
```

---

## Phase 12: Smoke Tests (10 minutes) ✅

**Verify everything works:**

```bash
# 1. Check KubeSphere health
kubectl get pods -n kubesphere-system

# 2. Check Kafka cluster
kubectl get kafka -n infrastructure
kubectl get kafkatopic -n infrastructure

# 3. Check PostgreSQL cluster
kubectl get cluster -n infrastructure
kubectl get pods -n infrastructure -l cnpg.io/cluster=infrastructure-postgres

# 4. Check applications
curl -k https://core-pipeline.dev.theedgestory.org/health
curl -k https://core-pipeline.theedgestory.org/health

# 5. Check monitoring
curl -k https://grafana.dev.theedgestory.org
curl -k https://prometheus.dev.theedgestory.org

# 6. Test Kafka connectivity
kubectl run kafka-producer-test --image=quay.io/strimzi/kafka:latest-kafka-3.8.0 --rm -ti --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server infrastructure-kafka-kafka-bootstrap.infrastructure.svc.cluster.local:9092 --topic core-pipeline-events

# Type a test message, then Ctrl+C

# 7. Test PostgreSQL connectivity
kubectl run psql-test --image=postgres:16 --rm -ti --restart=Never -- psql -h infrastructure-postgres-rw.infrastructure.svc.cluster.local -U core_dev_user -d core_pipeline_dev

# Enter password when prompted
```

---

## Summary: Migration Complete! 🎉

**What you now have:**

✅ **KubeSphere Platform** - Complete Kubernetes management UI
✅ **Strimzi Kafka** - Production-ready Kafka cluster (3 replicas)
✅ **CloudNativePG** - Cloud-native PostgreSQL with HA capabilities
✅ **Monitoring Stack** - Prometheus + Grafana integrated in KubeSphere
✅ **Logging Stack** - Elasticsearch + FluentBit for centralized logs
✅ **DevOps Pipeline** - Jenkins-based CI/CD in KubeSphere
✅ **Your Applications** - core-pipeline-dev & core-pipeline-prod running

**Access Points:**

- **KubeSphere Console**: https://kubesphere.dev.theedgestory.org
- **Dev Application**: https://core-pipeline.dev.theedgestory.org
- **Prod Application**: https://core-pipeline.theedgestory.org
- **Grafana**: https://grafana.dev.theedgestory.org
- **Prometheus**: https://prometheus.dev.theedgestory.org

**Next Steps:**

1. Change default KubeSphere password (admin/P@88w0rd)
2. Create user accounts for your team
3. Set up DevOps pipelines in KubeSphere for core-pipeline repo
4. Configure alerting rules for production
5. Set up backups for PostgreSQL (CloudNativePG has built-in backup)

---

## Rollback Plan (If Needed) ⏪

```bash
# 1. Restore from backups
kubectl apply -f /root/backup-before-kubesphere.yaml

# 2. Uninstall KubeSphere (keeps existing workloads)
kubectl delete namespace kubesphere-system
kubectl delete namespace kubesphere-monitoring-system
kubectl delete namespace kubesphere-logging-system

# 3. Restore old ArgoCD
kubectl apply -f argocd-apps/

# Your data is safe - KubeSphere doesn't touch existing namespaces
```

---

**Estimated Total Time**: 2-4 hours
**Recommended**: Do during low-traffic period
**Risk Level**: Low (can rollback easily)
