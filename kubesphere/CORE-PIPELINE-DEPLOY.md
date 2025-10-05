# Core-Pipeline Deployment Instructions

**For Repository**: https://github.com/uz0/core-pipeline

This guide shows how to deploy core-pipeline to the new KubeSphere platform.

---

## Prerequisites ✅

1. ✅ KubeSphere installed and running
2. ✅ Strimzi Kafka operator deployed
3. ✅ CloudNativePG PostgreSQL deployed
4. ✅ Namespaces created: `dev-core`, `prod-core`

---

## Step 1: Add Kubernetes Deployment Files to core-pipeline Repo

**In the `core-pipeline` repository, create these files:**

### File: `k8s/deployment-dev.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: core-pipeline
  namespace: dev-core
spec:
  replicas: 1
  selector:
    matchLabels:
      app: core-pipeline
  template:
    metadata:
      labels:
        app: core-pipeline
    spec:
      containers:
      - name: core-pipeline
        image: ghcr.io/uz0/core-pipeline:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "development"
        - name: POSTGRES_HOST
          value: "infrastructure-postgres-rw.infrastructure.svc.cluster.local"
        - name: POSTGRES_USER
          value: "core_dev_user"
        - name: POSTGRES_DB
          value: "core_pipeline_dev"
        - name: KAFKA_BROKERS
          value: "infrastructure-kafka-kafka-bootstrap.infrastructure.svc.cluster.local:9092"
        envFrom:
        - secretRef:
            name: core-pipeline-secrets
```

### File: `k8s/deployment-prod.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: core-pipeline
  namespace: prod-core
spec:
  replicas: 2  # Production HA
  selector:
    matchLabels:
      app: core-pipeline
  template:
    metadata:
      labels:
        app: core-pipeline
    spec:
      containers:
      - name: core-pipeline
        image: ghcr.io/uz0/core-pipeline:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: POSTGRES_HOST
          value: "infrastructure-postgres-rw.infrastructure.svc.cluster.local"
        - name: POSTGRES_USER
          value: "core_prod_user"
        - name: POSTGRES_DB
          value: "core_pipeline_prod"
        - name: KAFKA_BROKERS
          value: "infrastructure-kafka-kafka-bootstrap.infrastructure.svc.cluster.local:9092"
        envFrom:
        - secretRef:
            name: core-pipeline-secrets
```

---

## Step 2: Update GitHub Actions Workflow

**File: `.github/workflows/deploy.yml`**

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Login to GitHub Container Registry
      uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: |
          ghcr.io/uz0/core-pipeline:latest
          ghcr.io/uz0/core-pipeline:${{ github.sha }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  deploy-dev:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v4

    - name: Deploy to Dev
      run: |
        echo "${{ secrets.KUBECONFIG }}" > kubeconfig.yaml
        export KUBECONFIG=kubeconfig.yaml
        kubectl rollout restart deployment/core-pipeline -n dev-core
        kubectl rollout status deployment/core-pipeline -n dev-core --timeout=300s

  deploy-prod:
    needs: [build, deploy-dev]
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: production  # Requires manual approval
    steps:
    - uses: actions/checkout@v4

    - name: Deploy to Production
      run: |
        echo "${{ secrets.KUBECONFIG }}" > kubeconfig.yaml
        export KUBECONFIG=kubeconfig.yaml
        kubectl set image deployment/core-pipeline core-pipeline=ghcr.io/uz0/core-pipeline:${{ github.sha }} -n prod-core
        kubectl rollout status deployment/core-pipeline -n prod-core --timeout=300s
```

---

## Step 3: Configure GitHub Secrets

**In GitHub repo settings → Secrets and variables → Actions:**

Add secret: `KUBECONFIG`

**Value** (get from server):

```bash
# On server, generate kubeconfig for GitHub Actions
kubectl config view --minify --raw > /tmp/github-kubeconfig.yaml
cat /tmp/github-kubeconfig.yaml
# Copy the output and paste as KUBECONFIG secret in GitHub
```

---

## Step 4: Create Application Secrets

**On server:**

```bash
# Get actual PostgreSQL passwords from CloudNativePG
PGPASSWORD_DEV=$(kubectl get secret infrastructure-postgres-app -n infrastructure -o jsonpath='{.data.password}' | base64 -d)
PGPASSWORD_PROD=$(kubectl get secret infrastructure-postgres-app -n infrastructure -o jsonpath='{.data.password}' | base64 -d)

# Create secrets for dev
kubectl create secret generic core-pipeline-secrets -n dev-core \
  --from-literal=POSTGRES_PASSWORD="$PGPASSWORD_DEV" \
  --from-literal=KAFKA_USERNAME="core-pipeline-dev" \
  --from-literal=KAFKA_PASSWORD="not-used-for-plaintext" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create secrets for prod
kubectl create secret generic core-pipeline-secrets -n prod-core \
  --from-literal=POSTGRES_PASSWORD="$PGPASSWORD_PROD" \
  --from-literal=KAFKA_USERNAME="core-pipeline-prod" \
  --from-literal=KAFKA_PASSWORD="not-used-for-plaintext" \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## Step 5: Initial Manual Deployment

**Deploy using the manifests from core-charts repo:**

```bash
# Deploy dev
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/kubesphere/core-pipeline-dev.yaml

# Wait for dev to be ready
kubectl wait --for=condition=available --timeout=300s deployment/core-pipeline-dev -n dev-core

# Deploy prod
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/kubesphere/core-pipeline-prod.yaml

# Wait for prod to be ready
kubectl wait --for=condition=available --timeout=300s deployment/core-pipeline-prod -n prod-core
```

---

## Step 6: Verify Deployment

```bash
# Check pods
kubectl get pods -n dev-core
kubectl get pods -n prod-core

# Check logs
kubectl logs -f deployment/core-pipeline-dev -n dev-core
kubectl logs -f deployment/core-pipeline-prod -n prod-core

# Test endpoints
curl -k https://core-pipeline.dev.theedgestory.org/health
curl -k https://core-pipeline.theedgestory.org/health

# Test Kafka connection
kubectl exec -it deployment/core-pipeline-dev -n dev-core -- env | grep KAFKA

# Test PostgreSQL connection
kubectl exec -it deployment/core-pipeline-dev -n dev-core -- env | grep POSTGRES
```

---

## Step 7: Configure KubeSphere DevOps (Optional)

**Create pipeline in KubeSphere UI:**

1. Login to https://kubesphere.dev.theedgestory.org
2. Workspace: `core-pipeline` → DevOps → Create Pipeline
3. Name: `core-pipeline-cicd`
4. Type: GitHub
5. Repository: https://github.com/uz0/core-pipeline
6. Script Path: `Jenkinsfile` (create this file)

**File: `Jenkinsfile` in core-pipeline repo:**

```groovy
pipeline {
  agent any

  stages {
    stage('Build') {
      steps {
        container('maven') {
          sh 'npm install'
          sh 'npm run build'
        }
      }
    }

    stage('Test') {
      steps {
        container('maven') {
          sh 'npm test'
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        container('docker') {
          sh 'docker build -t ghcr.io/uz0/core-pipeline:$BUILD_NUMBER .'
          sh 'docker push ghcr.io/uz0/core-pipeline:$BUILD_NUMBER'
        }
      }
    }

    stage('Deploy to Dev') {
      steps {
        container('kubectl') {
          sh 'kubectl set image deployment/core-pipeline core-pipeline=ghcr.io/uz0/core-pipeline:$BUILD_NUMBER -n dev-core'
          sh 'kubectl rollout status deployment/core-pipeline -n dev-core'
        }
      }
    }

    stage('Deploy to Prod') {
      when {
        branch 'main'
      }
      input {
        message "Deploy to production?"
        ok "Deploy"
      }
      steps {
        container('kubectl') {
          sh 'kubectl set image deployment/core-pipeline core-pipeline=ghcr.io/uz0/core-pipeline:$BUILD_NUMBER -n prod-core'
          sh 'kubectl rollout status deployment/core-pipeline -n prod-core'
        }
      }
    }
  }
}
```

---

## Step 8: Monitor in KubeSphere

**Access monitoring:**

1. KubeSphere UI → Workspaces → core-pipeline
2. Projects → dev-core / prod-core
3. Application Workloads → Deployments → core-pipeline
4. View metrics:
   - CPU usage
   - Memory usage
   - Network I/O
   - Pod logs
   - Events

---

## Rollback Procedure

**If deployment fails:**

```bash
# Rollback dev
kubectl rollout undo deployment/core-pipeline-dev -n dev-core

# Rollback prod
kubectl rollout undo deployment/core-pipeline-prod -n prod-core

# Or rollback to specific revision
kubectl rollout history deployment/core-pipeline-prod -n prod-core
kubectl rollout undo deployment/core-pipeline-prod -n prod-core --to-revision=<number>
```

---

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod -n dev-core -l app=core-pipeline

# Check logs
kubectl logs -n dev-core -l app=core-pipeline --tail=100

# Common issues:
# 1. Image pull errors → Check GitHub package permissions
# 2. Database connection → Verify PostgreSQL is running
# 3. Kafka connection → Verify Kafka cluster is ready
```

### Database connectivity

```bash
# Test PostgreSQL connection from pod
kubectl exec -it deployment/core-pipeline-dev -n dev-core -- sh
# Inside pod:
nc -zv infrastructure-postgres-rw.infrastructure.svc.cluster.local 5432
```

### Kafka connectivity

```bash
# Test Kafka connection
kubectl exec -it deployment/core-pipeline-dev -n dev-core -- sh
# Inside pod:
nc -zv infrastructure-kafka-kafka-bootstrap.infrastructure.svc.cluster.local 9092
```

---

## Summary

✅ **Automated CI/CD** - GitHub Actions or KubeSphere DevOps
✅ **Health Monitoring** - Built-in KubeSphere monitoring
✅ **Easy Rollback** - One-command rollback capability
✅ **Environment Isolation** - Separate dev/prod namespaces
✅ **Production Ready** - HA configuration for prod (2 replicas)

**Your applications are now running on a production-grade Kubernetes platform! 🎉**
