# 🚀 Deploy OAuth Authentication NOW

## Quick Deploy (On Server)

SSH into the server and run:

```bash
ssh -i ~/.ssh/hetzner root@46.62.223.198

cd /root/core-charts
git pull origin main

# Run the automated deployment script
bash deploy-oauth.sh
```

The script will:
1. ✅ Check cluster connectivity
2. ✅ Check for OAuth secrets (optional)
3. ✅ Deploy Grafana with OAuth
4. ✅ Deploy Kafka UI with OAuth
5. ✅ Apply MinIO OAuth config
6. ✅ Apply Kubero OAuth config
7. ✅ Restart all services
8. ✅ Show service status

## With Google OAuth (Recommended)

If you want actual Google authentication, create OAuth secrets first:

```bash
# 1. Get OAuth credentials from Google Console
# https://console.cloud.google.com/apis/credentials

# 2. Set environment variables
export GOOGLE_CLIENT_ID='your-client-id-here'
export GOOGLE_CLIENT_SECRET='your-client-secret-here'

# 3. Create OAuth secrets in all namespaces
./auth/setup-google-oauth.sh

# 4. Deploy OAuth configurations
./deploy-oauth.sh
```

## Without OAuth Secrets

The deployments will work without OAuth secrets configured. Services will just use their default authentication methods until you add OAuth credentials.

## What Gets Deployed

| Service | Before | After (without secrets) | After (with secrets) |
|---------|--------|------------------------|---------------------|
| **Grafana** | admin/admin123 | admin/admin123 + OAuth config | Google OAuth enabled |
| **Kafka UI** | No auth | OAuth config (inactive) | Google OAuth required |
| **MinIO** | admin/password | admin/password + OAuth config | Google OAuth option |
| **Kubero** | Default auth | OAuth config (inactive) | Google OAuth required |

## Verify Deployment

After running `deploy-oauth.sh`, check:

```bash
# Check pods are running
kubectl get pods -n monitoring | grep -E "(grafana|kafka-ui)"
kubectl get pods -n minio | grep minio-tenant
kubectl get pods -n kubero | grep kubero

# Check OAuth secrets (if created)
kubectl get secret google-oauth -n monitoring
kubectl get secret google-oauth -n minio
kubectl get secret google-oauth -n kubero

# Test services
curl -I https://grafana.theedgestory.org
curl -I https://kafka.theedgestory.org
curl -I https://s3-admin.theedgestory.org
curl -I https://dev.theedgestory.org
```

## Deployment Annotations Status

Also deployed in this update:

✅ **Grafana Deployment Annotations**: Shows deployment markers on RED metrics dashboard
✅ **Clickable Log Links**: Deployment annotations link to Loki logs
✅ **Enhanced Deployment Tracking**: deployment-tracker.py with log URLs

Visit: http://grafana.theedgestory.org/d/core-pipeline-red/core-pipeline-red-metrics

You should see:
- Deployment markers on time-series graphs
- Clickable "📋 View Deployment Logs" links in annotations
- Commit info and deployment context

## Manual Deployment (If Script Fails)

```bash
# Apply each service individually
kubectl apply -f monitoring/deploy-grafana.yaml
kubectl apply -f monitoring/deploy-kafka-ui-oauth.yaml
kubectl apply -f minio/minio-oauth-config.yaml
kubectl apply -f kubero/kubero-oauth.yaml

# Restart services
kubectl rollout restart statefulset/grafana -n monitoring
kubectl rollout restart deployment/kafka-ui -n monitoring
kubectl rollout restart statefulset/minio-tenant-pool-0 -n minio
kubectl rollout restart deployment/kubero -n kubero

# Wait for rollouts
kubectl rollout status statefulset/grafana -n monitoring --timeout=300s
kubectl rollout status deployment/kafka-ui -n monitoring --timeout=300s
kubectl rollout status statefulset/minio-tenant-pool-0 -n minio --timeout=300s
kubectl rollout status deployment/kubero -n kubero --timeout=300s
```

## Troubleshooting

### Grafana shows "Client ID or Secret missing"

This is expected if you haven't created OAuth secrets yet. Grafana still works with admin/admin123.

To fix:
```bash
export GOOGLE_CLIENT_ID='...'
export GOOGLE_CLIENT_SECRET='...'
./auth/setup-google-oauth.sh
kubectl rollout restart statefulset/grafana -n monitoring
```

### Kafka UI pod CrashLoopBackOff

Check logs:
```bash
kubectl logs -n monitoring deployment/kafka-ui --tail=50
```

If it's OAuth-related, it will work once you add OAuth secrets.

### MinIO won't start

Check tenant logs:
```bash
kubectl logs -n minio statefulset/minio-tenant-pool-0 --tail=50
```

MinIO OAuth is optional - it will work without secrets.

### Deployment annotations not showing

1. Check deployment-tracker is running:
```bash
kubectl get pods -n monitoring | grep deployment-tracker
kubectl logs -n monitoring deployment/deployment-tracker
```

2. Rebuild and deploy if needed:
```bash
kubectl apply -f monitoring/deploy-deployment-tracker.yaml
```

## Next Steps After Deployment

1. **Visit Grafana**: Check deployment annotations at grafana.theedgestory.org
2. **Test OAuth (if configured)**: Try "Sign in with Google" on each service
3. **Configure domain restrictions**: Update OAuth configs to restrict to your domain
4. **Set up user roles**: Configure permissions in each service

## Complete Documentation

- **OAuth Setup**: `auth/OAUTH_DEPLOYMENT_GUIDE.md` (350+ lines)
- **Deployment Tracker**: `monitoring/deployment-tracker.py`
- **Grafana Dashboard**: `monitoring/grafana-dashboard-red.yaml`

## Summary

🎯 **Just run**: `bash deploy-oauth.sh`

That's it! Everything else is automated.
