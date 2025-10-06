# 🌌 Deploy The Edge Story Landing Page

## Quick Deploy (5 minutes)

SSH to server and run:

```bash
ssh -i ~/.ssh/hetzner root@46.62.223.198

cd /root/core-charts
git pull origin main

# Navigate to landing directory
cd landing

# Generate ConfigMap from HTML files
./create-configmap.sh

# Deploy to Kubernetes
kubectl apply -f landing-configmap.yaml
kubectl apply -f deploy-landing.yaml

# Wait for pods to be ready
kubectl rollout status deployment/landing-page --timeout=120s

# Verify deployment
kubectl get pods -l app=landing-page
kubectl get ingress landing-page
```

## What Gets Deployed

### 🌐 Main Landing Page
**URL:** https://theedgestory.org

Features:
- 🌌 Cosmic sci-fi aesthetic with animated stars
- ♾️ Description of endless story generation concept
- 🎮 Real-time multiplayer collaborative storytelling
- 🤖 AI-powered narrative generation
- 📱 Fully responsive mobile design
- ⚡ Fast, lightweight (static HTML)

### 🔒 Privacy Policy
**URL:** https://theedgestory.org/privacy-policy.html

Highlights:
- ✅ GDPR compliant
- ✅ Clear data collection practices
- ✅ "Development phase" disclosures
- ✅ **Only non-sensitive data collected**
- ✅ Intellectual property ownership disclosed
- ✅ User rights documented

### 📜 Terms of Service
**URL:** https://theedgestory.org/terms-of-service.html

Key Provisions:
- ✅ **All user content becomes property of The Edge Story**
- ✅ Perpetual, irrevocable IP rights transfer
- ✅ Development phase disclaimers
- ✅ Liability limitations
- ✅ Dispute resolution procedures
- ✅ Age restrictions (13+, 16+ in EU)

## Verify Deployment

After deploying, test all endpoints:

```bash
# Homepage
curl -I https://theedgestory.org
# Should return: HTTP/2 200

# Privacy Policy
curl -I https://theedgestory.org/privacy-policy.html
# Should return: HTTP/2 200

# Terms of Service
curl -I https://theedgestory.org/terms-of-service.html
# Should return: HTTP/2 200

# WWW redirect
curl -I https://www.theedgestory.org
# Should return: HTTP/2 301 (redirect to non-www)
```

## Architecture

```
User Browser
      ↓
theedgestory.org (DNS → 46.62.223.198)
      ↓
Traefik Ingress (TLS termination)
      ↓
landing-page Service
      ↓
Nginx Pods (2 replicas)
      ↓
ConfigMap (HTML content)
```

## Components Deployed

| Component | Type | Replicas | Purpose |
|-----------|------|----------|---------|
| **landing-page** | Deployment | 2 | Nginx serving static HTML |
| **landing-page** | Service | 1 | ClusterIP on port 80 |
| **landing-page** | Ingress | 1 | TLS + routing for theedgestory.org |
| **landing-page-www** | Ingress | 1 | WWW redirect |
| **landing-page** | ConfigMap | 1 | HTML files (index, privacy, terms) |
| **landing-nginx-config** | ConfigMap | 1 | Nginx configuration |
| **www-redirect** | Middleware | 1 | Traefik redirect rule |

## DNS Requirements

Ensure DNS A records point to LoadBalancer:

```
A     theedgestory.org       → 46.62.223.198
A     www.theedgestory.org   → 46.62.223.198
```

## TLS Certificates

Certificates are auto-provisioned by cert-manager:

```bash
# Check certificate status
kubectl get certificate landing-page-tls

# Should show: READY = True
```

If certificate issues:

```bash
# Check certificate details
kubectl describe certificate landing-page-tls

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager --tail=50
```

## Updating Content

To update landing page content in the future:

```bash
# 1. Edit HTML files locally
vim landing/index.html
vim landing/privacy-policy.html
vim landing/terms-of-service.html

# 2. Commit changes
git add landing/
git commit -m "Update landing page content"
git push origin main

# 3. On server, pull changes
cd /root/core-charts
git pull origin main
cd landing

# 4. Regenerate ConfigMap
./create-configmap.sh

# 5. Apply updated ConfigMap
kubectl apply -f landing-configmap.yaml

# 6. Restart pods to pick up changes
kubectl rollout restart deployment/landing-page

# 7. Verify
kubectl rollout status deployment/landing-page
curl -I https://theedgestory.org
```

## Monitoring

### Check Pod Status

```bash
# List pods
kubectl get pods -l app=landing-page

# Should show 2 pods in Running state
# Example output:
# NAME                            READY   STATUS    RESTARTS   AGE
# landing-page-5d8f7c9b4d-abc12   1/1     Running   0          5m
# landing-page-5d8f7c9b4d-def34   1/1     Running   0          5m
```

### Check Logs

```bash
# View nginx access logs
kubectl logs -l app=landing-page --tail=50

# Follow logs in real-time
kubectl logs -l app=landing-page -f
```

### Check Ingress

```bash
# View ingress details
kubectl describe ingress landing-page

# Check TLS secret
kubectl get secret landing-page-tls
```

## Troubleshooting

### Pods not starting

```bash
# Check pod events
kubectl describe pod -l app=landing-page

# Check ConfigMap exists
kubectl get configmap landing-page
kubectl get configmap landing-nginx-config

# Verify ConfigMap has content
kubectl get configmap landing-page -o yaml | grep "index.html" | head -5
```

### Ingress not working

```bash
# Check ingress events
kubectl describe ingress landing-page

# Verify Traefik is running
kubectl get pods -n kube-system | grep traefik

# Check cert-manager
kubectl get pods -n cert-manager
```

### Certificate issues

```bash
# Delete certificate and secret to force recreation
kubectl delete certificate landing-page-tls
kubectl delete secret landing-page-tls

# cert-manager will automatically recreate
# Wait 1-2 minutes, then check
kubectl get certificate landing-page-tls
```

### WWW redirect not working

```bash
# Check middleware
kubectl get middleware www-redirect -o yaml

# Check ingress annotation
kubectl describe ingress landing-page-www | grep middleware
```

## Performance

Expected performance metrics:

- **Page Load Time:** < 500ms
- **First Contentful Paint:** < 1s
- **Total Page Size:** ~16KB (index.html)
- **TLS Handshake:** < 100ms
- **Time to Interactive:** < 1.5s

## Security Features

✅ **TLS/HTTPS:** Let's Encrypt certificates
✅ **Security Headers:**
  - `X-Frame-Options: SAMEORIGIN`
  - `X-Content-Type-Options: nosniff`
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: no-referrer-when-downgrade`

✅ **Compression:** Gzip enabled for HTML/CSS/JS
✅ **Cache Control:** 1-year cache for static assets
✅ **Health Checks:** Liveness and readiness probes

## Legal Compliance

### ✅ GDPR Compliant

- Privacy Policy clearly states data practices
- Cookie notice integrated
- User rights documented
- Data retention policies defined
- International transfer notices

### ✅ IP Protection

**CRITICAL LEGAL PROVISION:**

From Terms of Service Section 3.2:

> "All content, narratives, stories, characters, worlds, plots, dialogue, descriptions, and creative works created by you on or through the Platform become the **exclusive, perpetual, and irrevocable property of The Edge Story** upon creation."

This is disclosed in:
- ✅ Terms of Service (multiple sections)
- ✅ Privacy Policy (Section 5)
- ✅ Footer of landing page

## What's Next

After deploying the landing page:

1. ✅ **Test all URLs** - Verify homepage, privacy policy, terms of service
2. ✅ **Check mobile responsiveness** - Open on phone/tablet
3. ✅ **Verify redirects** - WWW should redirect to non-WWW
4. ✅ **Monitor certificates** - Should auto-renew before expiry
5. 🔄 **Update content as needed** - Follow update procedure above

## Additional Deployments

The landing page is now ready. You may also want to deploy:

- **OAuth for infrastructure services** - Run `deploy-oauth.sh`
- **Deployment annotations** - Already deployed with Grafana
- **Monitoring** - Check https://grafana.theedgestory.org

## Summary

**Just run this on the server:**

```bash
cd /root/core-charts/landing
./create-configmap.sh
kubectl apply -f landing-configmap.yaml
kubectl apply -f deploy-landing.yaml
```

That's it! The Edge Story landing page will be live at https://theedgestory.org 🌌

---

**Note:** If DNS is not yet configured, you'll need to:
1. Set A records for theedgestory.org and www.theedgestory.org
2. Point both to 46.62.223.198 (LoadBalancer IP)
3. Wait for DNS propagation (5-30 minutes)
