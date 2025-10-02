# GitHub Webhook Setup Guide

This guide explains how to set up the webhook-based deployment system.

## Architecture

**Push-based GitOps workflow:**
1. Developer pushes code to `main` branch (or merges PR)
2. GitHub sends webhook to your server
3. Webhook receiver executes `deploy-hook.sh`
4. Script pulls latest code, builds charts, deploys to Kubernetes
5. Applications automatically update

**ArgoCD Role:** Visualization only, no automated sync

## Server Setup

### 1. Install Node.js (if not already installed)

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Install Express.js

```bash
cd ~/core-charts
npm install express
```

### 3. Configure the Webhook Receiver Service

```bash
# Copy service file to systemd
sudo cp webhook-receiver.service /etc/systemd/system/

# Edit the service file to set your webhook secret
sudo nano /etc/systemd/system/webhook-receiver.service
# Change: Environment="WEBHOOK_SECRET=your-secret-here"
# To:     Environment="WEBHOOK_SECRET=<generate-random-secret>"

# Reload systemd
sudo systemctl daemon-reload

# Enable and start the service
sudo systemctl enable webhook-receiver
sudo systemctl start webhook-receiver

# Check status
sudo systemctl status webhook-receiver
```

### 4. Open Firewall Port

```bash
# Allow webhook receiver port (3001)
sudo ufw allow 3001/tcp
```

### 5. Verify Service is Running

```bash
curl http://localhost:3001/health
# Should return: {"status":"ok","timestamp":"..."}
```

## GitHub Webhook Configuration

### 1. Generate Webhook Secret

```bash
# Generate a random secret
openssl rand -hex 32
# Copy this value - you'll need it for both GitHub and the service
```

### 2. Configure GitHub Webhook

1. Go to your GitHub repository
2. Navigate to **Settings** → **Webhooks** → **Add webhook**
3. Configure:
   - **Payload URL**: `http://your-server-ip:3001/webhook`
   - **Content type**: `application/json`
   - **Secret**: Paste the secret you generated above
   - **Which events**: Select "Just the push event"
   - **Active**: ✅ Checked

4. Click **Add webhook**

### 3. Update Service with Secret

```bash
# Edit the service file
sudo nano /etc/systemd/system/webhook-receiver.service

# Update the WEBHOOK_SECRET line with your generated secret
# Environment="WEBHOOK_SECRET=abc123..."

# Restart the service
sudo systemctl restart webhook-receiver
```

## Testing the Webhook

### 1. Test Locally

```bash
# Make a small change and push
echo "# Test" >> README.md
git add README.md
git commit -m "test: webhook trigger"
git push origin main
```

### 2. Monitor Deployment

```bash
# Watch webhook receiver logs
sudo journalctl -u webhook-receiver -f

# Watch pod deployments
kubectl get pods -n infrastructure -w
kubectl get pods -n dev-core -w
```

### 3. Check GitHub Webhook Deliveries

1. Go to GitHub → Settings → Webhooks
2. Click on your webhook
3. Go to "Recent Deliveries" tab
4. Check for successful deliveries (green checkmark)

## Image Tag Updates

When you build and push a new Docker image:

```bash
# Update the image tag for dev environment
./update-image-tag.sh dev main-abc123

# Update the image tag for prod environment  
./update-image-tag.sh prod main-abc123
```

This will:
1. Update the values file with the new image tag
2. Commit and push the change
3. Trigger the webhook automatically
4. Deploy the new image

## Troubleshooting

### Webhook not triggering deployment

```bash
# Check webhook receiver status
sudo systemctl status webhook-receiver

# Check logs
sudo journalctl -u webhook-receiver -n 50

# Test webhook receiver manually
curl -X POST http://localhost:3001/webhook \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/main","repository":{"full_name":"test/repo"}}'
```

### Deployment fails

```bash
# Check deploy-hook.sh logs (they appear in webhook receiver logs)
sudo journalctl -u webhook-receiver -n 100

# Run deploy script manually for debugging
cd ~/core-charts
bash -x ./deploy-hook.sh
```

### Signature verification fails

```bash
# Check if secret matches in both places:
# 1. GitHub webhook settings
# 2. /etc/systemd/system/webhook-receiver.service

# If you need to disable signature verification temporarily:
# Set WEBHOOK_SECRET="" in the service file (NOT RECOMMENDED for production)
```

## Security Recommendations

1. **Use HTTPS**: Set up a reverse proxy (nginx/traefik) with SSL for the webhook endpoint
2. **Restrict Access**: Use firewall rules to only allow GitHub IPs
3. **Strong Secret**: Use a long, random webhook secret (minimum 32 characters)
4. **Monitor Logs**: Regularly check webhook receiver logs for suspicious activity
5. **Rate Limiting**: Consider adding rate limiting to prevent abuse

## Workflow Summary

**Normal Development Flow:**
```
Code Change → Push to main → Webhook → deploy-hook.sh → Kubernetes Update
```

**Image Update Flow:**
```
Build Image → Push to Registry → update-image-tag.sh → Git Commit → Webhook → Deploy
```

**Manual Deployment (if needed):**
```bash
cd ~/core-charts
./deploy-hook.sh
```
