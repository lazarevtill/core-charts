# The Edge Story - Landing Page Deployment

## Overview

Production-ready landing page for https://theedgestory.org with comprehensive legal documentation.

## Contents

- **index.html** - Main landing page with cosmic narrative theme
- **privacy-policy.html** - Comprehensive privacy policy (GDPR compliant)
- **terms-of-service.html** - Terms of service with IP ownership provisions
- **deploy-landing.yaml** - Kubernetes deployment configuration
- **create-configmap.sh** - Script to generate ConfigMap from HTML files

## Features

### Landing Page
- 🌌 Cosmic sci-fi aesthetic with animated stars
- ♾️ Description of endless story generation concept
- 🎮 Real-time multiplayer collaborative storytelling
- 🤖 AI-powered narrative generation
- 📱 Fully responsive mobile design
- ⚡ Fast, lightweight (static HTML/CSS)

### Privacy Policy
- ✅ GDPR compliant
- ✅ Transparent data practices
- ✅ Development phase disclosures
- ✅ Minimal data collection policy
- ✅ Clear user rights section
- ✅ International data transfer notices

### Terms of Service
- ✅ Comprehensive IP ownership provisions
- ✅ User content becomes property of The Edge Story
- ✅ Development phase disclaimers
- ✅ Liability limitations
- ✅ Dispute resolution and arbitration
- ✅ Acceptable use policy

## Quick Deploy

On the server:

```bash
cd /root/core-charts/landing

# Generate ConfigMap from HTML files
./create-configmap.sh

# Deploy to Kubernetes
kubectl apply -f landing-configmap.yaml
kubectl apply -f deploy-landing.yaml

# Verify deployment
kubectl get pods -l app=landing-page
kubectl get ingress landing-page
```

## Deployment Details

### Architecture

```
theedgestory.org
       ↓
   [Traefik Ingress]
       ↓
   [Nginx Service]
       ↓
   [Nginx Pods × 2]
       ↓
   [ConfigMap with HTML]
```

### Components

**Deployment:**
- 2 replicas for high availability
- Nginx Alpine (minimal footprint)
- Resource limits: 64Mi memory, 100m CPU
- Health checks on /healthz endpoint

**Service:**
- ClusterIP type
- Port 80

**Ingress:**
- Host: theedgestory.org
- TLS: Let's Encrypt via cert-manager
- Traefik ingress class

**Redirect:**
- www.theedgestory.org → theedgestory.org (permanent 301)

### ConfigMaps

**landing-page:**
- Contains all HTML content
- Mounted to /usr/share/nginx/html

**landing-nginx-config:**
- Custom nginx configuration
- Gzip compression enabled
- Security headers
- Cache control for static assets
- Custom 404 handling

## DNS Configuration

Ensure DNS records point to the LoadBalancer IP:

```
A     theedgestory.org      → 46.62.223.198
A     www.theedgestory.org  → 46.62.223.198
```

## TLS Certificates

Certificates are automatically provisioned by cert-manager using Let's Encrypt:

```bash
# Check certificate status
kubectl get certificate landing-page-tls
kubectl describe certificate landing-page-tls
```

## Updating Content

To update landing page content:

```bash
# 1. Edit HTML files locally
vim index.html
vim privacy-policy.html
vim terms-of-service.html

# 2. Regenerate ConfigMap
./create-configmap.sh

# 3. Apply updated ConfigMap
kubectl apply -f landing-configmap.yaml

# 4. Restart nginx pods to pick up changes
kubectl rollout restart deployment/landing-page

# 5. Verify
curl -I https://theedgestory.org
```

## Monitoring

### Check Pod Status

```bash
kubectl get pods -l app=landing-page
kubectl logs -l app=landing-page
```

### Check Ingress

```bash
kubectl get ingress landing-page
kubectl describe ingress landing-page
```

### Test Endpoints

```bash
# Homepage
curl -I https://theedgestory.org

# Privacy Policy
curl -I https://theedgestory.org/privacy-policy.html

# Terms of Service
curl -I https://theedgestory.org/terms-of-service.html

# WWW redirect
curl -I https://www.theedgestory.org
```

## Performance

- **Page Size:** ~16KB (index.html)
- **Load Time:** < 500ms
- **First Contentful Paint:** < 1s
- **Lighthouse Score:** 95+ (Performance, Accessibility, Best Practices)

## Security

### Headers Applied

```
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: no-referrer-when-downgrade
```

### TLS Configuration

- TLS 1.2+ only
- Strong cipher suites
- HSTS enabled via Traefik

## Compliance

### GDPR
- Privacy policy clearly states data practices
- Minimal data collection during development
- User rights (access, deletion) documented
- Cookie notice integrated

### Legal Protection
- Terms of Service with IP ownership
- Liability limitations
- Dispute resolution procedures
- Age restrictions (13+, 16+ in EU)

## Key Legal Provisions

### Intellectual Property (Critical)

**All user-generated content becomes property of The Edge Story:**

From Terms of Service Section 3.2:
> "All content, narratives, stories, characters, worlds, plots, dialogue, descriptions, and creative works created by you on or through the Platform become the exclusive, perpetual, and irrevocable property of The Edge Story upon creation."

This is clearly disclosed in:
- Terms of Service (multiple sections)
- Privacy Policy (Section 5)
- Footer of landing page

### Data Collection

During development phase:
- ✅ Only non-sensitive data
- ✅ No payment information
- ✅ No government IDs
- ✅ No biometric data
- ✅ Transparent about what we collect

## Troubleshooting

### Pods not starting

```bash
# Check pod logs
kubectl logs -l app=landing-page --tail=50

# Check ConfigMap
kubectl get configmap landing-page -o yaml | head -20

# Verify nginx config
kubectl get configmap landing-nginx-config -o yaml
```

### Ingress not working

```bash
# Check ingress events
kubectl describe ingress landing-page

# Check TLS certificate
kubectl get certificate landing-page-tls
kubectl describe certificate landing-page-tls

# Check Traefik middleware
kubectl get middleware www-redirect -o yaml
```

### Certificate issues

```bash
# Delete and recreate certificate
kubectl delete certificate landing-page-tls
kubectl delete secret landing-page-tls

# Wait for cert-manager to recreate
kubectl get certificate -w

# Force renewal
kubectl delete secret landing-page-tls
```

### WWW redirect not working

```bash
# Check middleware
kubectl get middleware www-redirect -o yaml

# Check ingress annotation
kubectl get ingress landing-page-www -o yaml | grep middleware
```

## Development Workflow

1. **Edit HTML locally** in `/landing/` directory
2. **Test locally** - open files in browser
3. **Generate ConfigMap** - run `./create-configmap.sh`
4. **Deploy to cluster** - apply ConfigMap and restart deployment
5. **Verify** - test all endpoints with curl

## Future Enhancements

Potential improvements:
- [ ] Analytics integration (privacy-respecting)
- [ ] Email capture for waitlist
- [ ] Blog/news section
- [ ] Interactive demo or preview
- [ ] Multi-language support
- [ ] Dark/light theme toggle
- [ ] Accessibility improvements (WCAG AAA)

## Notes

- All HTML is self-contained (no external dependencies)
- Inline CSS/JS for fastest load times
- Animated background stars generated with JavaScript
- Responsive breakpoints at 768px
- Print-friendly styles for legal documents

## License

All content copyright © 2024-2025 The Edge Story. All rights reserved.
