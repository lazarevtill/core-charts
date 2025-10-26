# DCMaidBot Manifest Update - Deployment Instructions

## Overview

This update aligns the dcmaidbot Helm chart with the upcoming changes in `dcversus/dcmaidbot` PR #3 (prp-001-infrastructure-cleanup).

## Changes Summary

### Environment Variables Updated

**New Configuration:**
- `BOT_TOKEN` - Telegram bot API token (required)
- `ADMIN_IDS` - Comma-separated admin Telegram user IDs (required)

**Removed:**
- `ADMIN_VASILISA_ID` → Merged into `ADMIN_IDS`
- `ADMIN_DANIIL_ID` → Merged into `ADMIN_IDS`
- `DATABASE_URL` → Not used in PR #3
- `OPENAI_API_KEY` → Not used in PR #3
- `DEBUG` → Not used in PR #3
- `REDIS_URL` → Not used in PR #3

## Deployment Steps

### Step 1: Create Pull Request

Create a PR from the branch:
```bash
# Visit the GitHub link from the push output:
# https://github.com/uz0/core-charts/pull/new/claude/sync-manifest-params-011CUW91SYeMeuoksgLcNMgT
```

Or merge directly:
```bash
git checkout main
git merge claude/sync-manifest-params-011CUW91SYeMeuoksgLcNMgT
git push origin main
```

### Step 2: Update Kubernetes Secret

The `dcmaidbot-secrets` secret needs to be updated with the new format.

#### Current Secret Format (Old)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dcmaidbot-secrets
  namespace: default  # or your namespace
type: Opaque
stringData:
  bot-token: "your_bot_token_here"
  admin-vasilisa-id: "123456789"
  admin-daniil-id: "987654321"
  database-url: "postgresql://..."
  openai-api-key: "sk-..."
```

#### New Secret Format (Updated)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dcmaidbot-secrets
  namespace: default  # or your namespace
type: Opaque
stringData:
  bot-token: "your_bot_token_here"
  admin-ids: "123456789,987654321"  # Comma-separated list
```

#### Update the Secret

**Option A: Using kubectl (Recommended)**
```bash
# Get the current bot token
BOT_TOKEN=$(kubectl get secret dcmaidbot-secrets -o jsonpath='{.data.bot-token}' | base64 -d)

# Get the current admin IDs
VASILISA_ID=$(kubectl get secret dcmaidbot-secrets -o jsonpath='{.data.admin-vasilisa-id}' | base64 -d)
DANIIL_ID=$(kubectl get secret dcmaidbot-secrets -o jsonpath='{.data.admin-daniil-id}' | base64 -d)

# Create the new secret
kubectl create secret generic dcmaidbot-secrets \
  --from-literal=bot-token="$BOT_TOKEN" \
  --from-literal=admin-ids="$VASILISA_ID,$DANIIL_ID" \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Option B: Manual Edit**
```bash
# Edit the secret directly
kubectl edit secret dcmaidbot-secrets

# Then manually:
# 1. Remove: admin-vasilisa-id, admin-daniil-id, database-url, openai-api-key
# 2. Add: admin-ids with base64-encoded comma-separated IDs
```

**Option C: Using Sealed Secrets (GitOps)**

If using sealed-secrets:
```bash
# Create new secret file
cat > dcmaidbot-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: dcmaidbot-secrets
  namespace: default
type: Opaque
stringData:
  bot-token: "your_bot_token_here"
  admin-ids: "123456789,987654321"
EOF

# Seal it
kubeseal --format=yaml < dcmaidbot-secret.yaml > dcmaidbot-sealed-secret.yaml

# Commit to repo
git add dcmaidbot-sealed-secret.yaml
git commit -m "Update dcmaidbot secret format"
git push
```

### Step 3: Verify the Changes

Check that ArgoCD picks up the changes:
```bash
# Check ArgoCD sync status
kubectl get application dcmaidbot -n argocd

# Or manually sync
kubectl patch application dcmaidbot -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' --type=merge
```

### Step 4: Restart the Deployment

After updating the secret, restart dcmaidbot:
```bash
kubectl rollout restart deployment dcmaidbot
kubectl rollout status deployment dcmaidbot
```

### Step 5: Verify Bot is Running

Check logs:
```bash
# Check pod status
kubectl get pods -l app=dcmaidbot

# View logs
kubectl logs -l app=dcmaidbot --tail=100 -f
```

Expected log output:
```
INFO: Loaded 2 admin(s) from ADMIN_IDS
INFO: Bot started successfully
```

### Step 6: Test Bot Functionality

Send a test message to the bot on Telegram to confirm it responds correctly.

## Rollback Plan

If issues occur, rollback to the previous version:

```bash
# Revert the manifest changes
git checkout main
git revert HEAD
git push origin main

# Restore the old secret format
kubectl apply -f old-dcmaidbot-secret.yaml

# Restart deployment
kubectl rollout restart deployment dcmaidbot
```

## Timeline Coordination

**Important:** This update should be deployed **after** dcversus/dcmaidbot PR #3 is merged and the new container image is built.

1. ✅ PR #3 merged in dcversus/dcmaidbot
2. ✅ New container image published to GHCR
3. ✅ Merge this manifest update
4. ✅ Update Kubernetes secret
5. ✅ Deploy via ArgoCD

## Support

If you encounter issues:
1. Check pod logs: `kubectl logs -l app=dcmaidbot`
2. Check secret exists: `kubectl get secret dcmaidbot-secrets`
3. Verify secret keys: `kubectl get secret dcmaidbot-secrets -o yaml`
4. Check ArgoCD status: `kubectl get application dcmaidbot -n argocd`

## Notes

- The new `ADMIN_IDS` format allows unlimited admins (not just 2)
- Admin IDs are never logged (privacy-first design in PR #3)
- Storage defaults to JSON file if no database configured
- No database or OpenAI dependencies in this version
