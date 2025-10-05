# KubeSphere v4 Installation Guide

Complete step-by-step guide to install KubeSphere v4.1.3 platform with all components.

**Time**: ~40 minutes
**Server**: root@ubuntu-16gb-hel1-1 (46.62.223.198)

---

## Phase 1: Install KubeSphere Core (5 minutes)

### Step 1.1: Install Helm (if not installed)

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Step 1.2: Install KubeSphere v4 Core

```bash
helm upgrade --install -n kubesphere-system --create-namespace \
  ks-core https://charts.kubesphere.io/main/ks-core-1.1.4.tgz \
  --debug --wait
```

**Wait ~3-5 minutes** for pods to be ready.

### Step 1.3: Verify Installation

```bash
# Check all pods are running
kubectl get pods -n kubesphere-system

# Expected output: All pods should be Running (1/1 or 2/2)
# - ks-apiserver
# - ks-console
# - ks-controller-manager
```

### Step 1.4: Get Admin Credentials

```bash
# Get password
kubectl get secret -n kubesphere-system ks-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo  # Add newline

# Get NodePort
kubectl get svc -n kubesphere-system ks-console -o jsonpath='{.spec.ports[0].nodePort}'
echo

# Save these values!
```

### Step 1.5: Test Access

```bash
# Open in browser
# URL: http://46.62.223.198:<NODEPORT>
# Username: admin
# Password: (from step 1.4)
```

✅ **Phase 1 Complete!** KubeSphere Core is installed.

---

## Phase 2: Configure HTTPS Ingress (2 minutes)

### Step 2.1: Create Ingress Manifest

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
                  number: 30880
EOF

kubectl apply -f /tmp/kubesphere-ingress.yaml
```

### Step 2.2: Verify HTTPS Access

```bash
# Wait 30 seconds for cert-manager
sleep 30

# Check certificate
kubectl get certificate -n kubesphere-system

# Access via HTTPS
# URL: https://kubesphere.dev.theedgestory.org
```

✅ **Phase 2 Complete!** HTTPS access configured.

---

## Phase 3: Install Extensions (10 minutes)

KubeSphere v4 uses an **Extension Center** for all components.

### Step 3.1: Install Monitoring (WhizardTelemetry)

**Via Web UI:**

1. Login to https://kubesphere.dev.theedgestory.org
2. Click **"Extension Marketplace"** (top right)
3. Search for **"WhizardTelemetry Monitoring"**
4. Click **Install** → Select version → Next
5. Review settings → Click **Install**

**Wait ~3 minutes** for installation.

### Step 3.2: Install Logging (WhizardTelemetry)

1. Extension Marketplace → Search **"WhizardTelemetry Logging"**
2. Install → Accept defaults → Install

**Wait ~2 minutes**.

### Step 3.3: Install DevOps (Optional)

1. Extension Marketplace → Search **"DevOps"**
2. Install → Configure:
   - Enable Argo CD: Yes
   - Enable Jenkins: Yes (if you want pipelines)
3. Install

**Wait ~3 minutes**.

### Step 3.4: Verify Extensions

```bash
# List installed extensions
kubectl get extensions -A

# Check extension pods
kubectl get pods -A | grep -E 'whizard|devops'
```

✅ **Phase 3 Complete!** Monitoring, Logging, DevOps installed.

---

## Phase 4: Deploy Infrastructure (15 minutes)

### Step 4.1: Install CloudNativePG Operator

```bash
# Install PostgreSQL operator
kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml

# Verify operator
kubectl get pods -n cnpg-system
```

### Step 4.2: Deploy PostgreSQL Cluster

```bash
cat > /tmp/postgres-cluster.yaml << 'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: infrastructure-postgres
  namespace: infrastructure
spec:
  instances: 1

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
        - CREATE USER core_dev_user WITH PASSWORD 'dev_password_CHANGE_ME';
        - GRANT ALL PRIVILEGES ON DATABASE core_pipeline_dev TO core_dev_user;
        - CREATE DATABASE core_pipeline_prod;
        - CREATE USER core_prod_user WITH PASSWORD 'prod_password_CHANGE_ME';
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

# Create infrastructure namespace
kubectl create namespace infrastructure

# IMPORTANT: Edit passwords before applying!
kubectl apply -f /tmp/postgres-cluster.yaml

# Wait for cluster
kubectl wait cluster/infrastructure-postgres --for=jsonpath='{.status.phase}'=Cluster in healthy state --timeout=300s -n infrastructure
```

### Step 4.3: Install Strimzi Kafka Operator

```bash
# Add Helm repo
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Create namespace
kubectl create namespace kafka-operator

# Install Strimzi
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka-operator \
  --set watchNamespaces="{infrastructure}" \
  --wait

# Verify
kubectl get pods -n kafka-operator
```

### Step 4.4: Deploy Kafka Cluster

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
    retention.ms: 604800000
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
    retention.ms: 259200000
EOF

kubectl apply -f /tmp/kafka-cluster.yaml

# Wait for Kafka (~5 min)
kubectl wait kafka/infrastructure-kafka --for=condition=Ready --timeout=600s -n infrastructure
```

### Step 4.5: Install Redis (Optional)

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install infrastructure-redis bitnami/redis \
  --namespace infrastructure \
  --set architecture=standalone \
  --set auth.enabled=true \
  --set auth.password=redis_password_CHANGE_ME \
  --set master.persistence.enabled=false \
  --wait
```

✅ **Phase 4 Complete!** Infrastructure deployed (PostgreSQL + Kafka + Redis).

---

## Phase 5: Deploy Applications (5 minutes)

### Step 5.1: Create Namespaces

```bash
# Create via KubeSphere UI
# Workspaces → Create Workspace: "core-pipeline"
# In workspace → Create Project: "dev-core"
# In workspace → Create Project: "prod-core"

# Or via CLI
kubectl create namespace dev-core
kubectl create namespace prod-core
```

### Step 5.2: Deploy Dev Application

```bash
# Manifests will be in core-charts repo
cd ~/core-charts
git pull

kubectl apply -f k8s/apps/dev/core-pipeline.yaml
```

### Step 5.3: Deploy Prod Application

```bash
kubectl apply -f k8s/apps/prod/core-pipeline.yaml
```

### Step 5.4: Verify Deployments

```bash
# Check pods
kubectl get pods -n dev-core
kubectl get pods -n prod-core

# Check ingresses
kubectl get ingress -A

# Test endpoints
curl -k https://core-pipeline.dev.theedgestory.org/health
curl -k https://core-pipeline.theedgestory.org/health
```

✅ **Phase 5 Complete!** Applications deployed.

---

## Verification Checklist

```bash
# ✅ KubeSphere Core
kubectl get pods -n kubesphere-system
# All pods Running

# ✅ Extensions
kubectl get extensions -A
# whizard-monitoring, whizard-logging installed

# ✅ PostgreSQL
kubectl get cluster -n infrastructure
# STATUS: Cluster in healthy state

# ✅ Kafka
kubectl get kafka -n infrastructure
# READY: True

# ✅ Redis
kubectl get pods -n infrastructure -l app.kubernetes.io/name=redis
# Running

# ✅ Applications
kubectl get pods -n dev-core
kubectl get pods -n prod-core
# Running

# ✅ Ingresses
kubectl get ingress -A
# All have ADDRESS assigned
```

---

## Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| KubeSphere | https://kubesphere.dev.theedgestory.org | admin / (from step 1.4) |
| Grafana | KubeSphere → Monitoring | Same as KubeSphere |
| Dev App | https://core-pipeline.dev.theedgestory.org | - |
| Prod App | https://core-pipeline.theedgestory.org | - |

---

## Next Steps

1. **Change admin password** (in KubeSphere UI → User Settings)
2. **Create user accounts** for your team
3. **Configure monitoring alerts** (in Monitoring extension)
4. **Set up CI/CD pipeline** (in DevOps extension)
5. **Configure backups** (PostgreSQL has built-in backup in CloudNativePG)

---

## Troubleshooting

### Extensions not appearing

```bash
# Refresh extension catalog
kubectl patch extensioncatalog kubesphere-marketplace -n kubesphere-system \
  -p '{"spec":{"lastSyncTime":null}}' --type merge
```

### Pods not starting

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Certificate issues

```bash
kubectl describe certificate <cert-name> -n <namespace>
kubectl get challenges -A
```

---

## Rollback

If something goes wrong:

```bash
# Uninstall KubeSphere (keeps your apps)
helm uninstall ks-core -n kubesphere-system

# Or full cleanup
kubectl delete namespace kubesphere-system
```

---

**Installation Complete!** 🎉

Your KubeSphere v4 platform is ready with:
- ✅ Monitoring & Logging
- ✅ PostgreSQL, Kafka, Redis
- ✅ Dev & Prod applications

Access: **https://kubesphere.dev.theedgestory.org**
