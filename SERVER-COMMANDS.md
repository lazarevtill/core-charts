# 🚀 Server Commands - KubeSphere Migration

**Execute these commands on your server**: `root@ubuntu-16gb-hel1-1`

---

## Quick Start (TL;DR)

```bash
cd ~/core-charts
git pull origin main
bash kubesphere-install.sh
```

Then follow: [MIGRATION-TO-KUBESPHERE.md](./MIGRATION-TO-KUBESPHERE.md)

---

## Step-by-Step Commands

### 1. Pull Latest Code

```bash
cd ~/core-charts
git pull origin main
```

**Expected files**:
- ✅ `MIGRATION-TO-KUBESPHERE.md` - Complete migration guide
- ✅ `kubesphere-install.sh` - Installation script
- ✅ `kubesphere/core-pipeline-dev.yaml` - Dev deployment manifest
- ✅ `kubesphere/core-pipeline-prod.yaml` - Prod deployment manifest
- ✅ `kubesphere/CORE-PIPELINE-DEPLOY.md` - core-pipeline deployment guide

---

### 2. Backup Current State (IMPORTANT!)

```bash
# Create backup directory
mkdir -p ~/kubesphere-backup-$(date +%Y%m%d)

# Backup all Kubernetes resources
kubectl get all -A -o yaml > ~/kubesphere-backup-$(date +%Y%m%d)/all-resources.yaml

# Backup secrets (CRITICAL - needed for restore)
kubectl get secret -n infrastructure -o yaml > ~/kubesphere-backup-$(date +%Y%m%d)/secrets-infrastructure.yaml
kubectl get secret -n dev-core -o yaml > ~/kubesphere-backup-$(date +%Y%m%d)/secrets-dev.yaml
kubectl get secret -n prod-core -o yaml > ~/kubesphere-backup-$(date +%Y%m%d)/secrets-prod.yaml

# Backup ingresses
kubectl get ingress -A -o yaml > ~/kubesphere-backup-$(date +%Y%m%d)/ingresses.yaml

echo "✅ Backup complete in ~/kubesphere-backup-$(date +%Y%m%d)/"
```

---

### 3. Install KubeSphere (One Command!)

```bash
cd ~/core-charts
bash kubesphere-install.sh
```

**What this does**:
- ✅ Checks prerequisites (K3s, storage class)
- ✅ Creates automatic backup
- ✅ Installs KubeSphere 3.4.1
- ✅ Monitors installation progress (~10-15 minutes)
- ✅ Shows access credentials

**Expected output**:
```
✅ KubeSphere Installation Complete!
🌐 Console URL: http://46.62.223.198:30880
👤 Username: admin
🔑 Password: P@88w0rd
```

---

### 4. Access KubeSphere UI

```bash
# Open in browser:
http://46.62.223.198:30880

# Login:
Username: admin
Password: P@88w0rd

# IMPORTANT: Change password immediately!
```

---

### 5. Configure HTTPS Ingress for KubeSphere

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

**Now access via**: https://kubesphere.dev.theedgestory.org

---

### 6. Enable KubeSphere Components

```bash
# Edit configuration
kubectl edit cm ks-installer -n kubesphere-system

# Change these from `false` to `true`:
# - devops.enabled: true
# - monitoring.enabled: true (with storageClass: local-path)
# - logging.enabled: true
# - alerting.enabled: true
# - events.enabled: true

# Save and exit (Ctrl+X, Y, Enter in nano)

# Watch components install
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f
```

**Wait ~5-10 minutes** for components to install.

---

### 7. Install Strimzi Kafka Operator

```bash
# Add Helm repo
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Create namespace
kubectl create namespace kafka-operator

# Install operator
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka-operator \
  --set watchNamespaces="{infrastructure}" \
  --wait

# Verify
kubectl get pods -n kafka-operator
```

**Deploy Kafka cluster**:

```bash
# Download Kafka cluster manifest from repo
curl -o /tmp/kafka-cluster.yaml https://raw.githubusercontent.com/uz0/core-charts/main/kubesphere/kafka-cluster.yaml

# Or create inline:
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
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
    storage:
      type: ephemeral
  zookeeper:
    replicas: 3
    storage:
      type: ephemeral
EOF

kubectl apply -f /tmp/kafka-cluster.yaml

# Wait for Kafka to be ready
kubectl wait kafka/infrastructure-kafka --for=condition=Ready --timeout=300s -n infrastructure
```

---

### 8. Install CloudNativePG PostgreSQL Operator

```bash
# Install operator
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml

# Verify
kubectl get pods -n cnpg-system

# Create PostgreSQL cluster
cat > /tmp/postgresql-cluster.yaml << 'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: infrastructure-postgres
  namespace: infrastructure
spec:
  instances: 1
  bootstrap:
    initdb:
      database: postgres
      owner: postgres
      postInitSQL:
        - CREATE DATABASE core_pipeline_dev;
        - CREATE USER core_dev_user WITH PASSWORD 'CHANGE_PASSWORD_DEV';
        - GRANT ALL PRIVILEGES ON DATABASE core_pipeline_dev TO core_dev_user;
        - CREATE DATABASE core_pipeline_prod;
        - CREATE USER core_prod_user WITH PASSWORD 'CHANGE_PASSWORD_PROD';
        - GRANT ALL PRIVILEGES ON DATABASE core_pipeline_prod TO core_prod_user;
  storage:
    size: 10Gi
EOF

# IMPORTANT: Change passwords above before applying!
kubectl apply -f /tmp/postgresql-cluster.yaml
```

---

### 9. Deploy Core-Pipeline Applications

```bash
# Update passwords in manifests first!
kubectl apply -f ~/core-charts/kubesphere/core-pipeline-dev.yaml
kubectl apply -f ~/core-charts/kubesphere/core-pipeline-prod.yaml

# Watch deployment
kubectl get pods -n dev-core -w
kubectl get pods -n prod-core -w
```

---

### 10. Verify Everything Works

```bash
# Check KubeSphere
kubectl get pods -n kubesphere-system

# Check Kafka
kubectl get kafka -n infrastructure

# Check PostgreSQL
kubectl get cluster -n infrastructure

# Check applications
kubectl get pods -n dev-core
kubectl get pods -n prod-core

# Test endpoints
curl -k https://core-pipeline.dev.theedgestory.org/health
curl -k https://core-pipeline.theedgestory.org/health
```

---

## Rollback (If Needed)

```bash
# Restore from backup
cd ~/kubesphere-backup-YYYYMMDD/
kubectl apply -f all-resources.yaml

# Uninstall KubeSphere
kubectl delete namespace kubesphere-system
kubectl delete namespace kubesphere-monitoring-system
kubectl delete namespace kubesphere-logging-system
```

---

## Access Points After Migration

| Service | URL |
|---------|-----|
| **KubeSphere Console** | https://kubesphere.dev.theedgestory.org |
| **Dev Application** | https://core-pipeline.dev.theedgestory.org |
| **Prod Application** | https://core-pipeline.theedgestory.org |
| **Grafana** | Integrated in KubeSphere |
| **Prometheus** | Integrated in KubeSphere |

---

## Next: core-pipeline Repository

After server migration is complete, update your **core-pipeline** repository:

**See**: `kubesphere/CORE-PIPELINE-DEPLOY.md` for instructions.

---

## Help & Troubleshooting

**Installation stuck?**
```bash
kubectl logs -n kubesphere-system -l app=ks-installer --tail=100
```

**Pods not starting?**
```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Need more info?**
```bash
# Full migration guide
cat ~/core-charts/MIGRATION-TO-KUBESPHERE.md

# core-pipeline deployment guide
cat ~/core-charts/kubesphere/CORE-PIPELINE-DEPLOY.md
```

---

**🎉 That's it! You now have a production-grade Kubernetes platform!**
