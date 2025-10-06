# DNS Configuration for theedgestory.org

## GitHub Pages Setup

The landing page (https://theedgestory.org) is hosted on GitHub Pages.

### Required DNS Records

Add the following DNS records to your domain registrar:

#### A Records (for apex domain)
```
Type: A
Name: @
Value: 185.199.108.153

Type: A
Name: @
Value: 185.199.109.153

Type: A  
Name: @
Value: 185.199.110.153

Type: A
Name: @
Value: 185.199.111.153
```

#### CNAME Record (for www subdomain)
```
Type: CNAME
Name: www
Value: uz0.github.io
```

### GitHub Repository Settings

1. Go to https://github.com/uz0/theedgestory.org/settings/pages
2. Under "Custom domain", enter: `theedgestory.org`
3. Check "Enforce HTTPS"
4. The CNAME file in the repo will be automatically respected

### Verification

After DNS propagation (can take up to 24-48 hours):

- https://theedgestory.org should serve the landing page
- https://www.theedgestory.org should redirect to https://theedgestory.org
- GitHub Pages will automatically provision Let's Encrypt SSL certificate

### Deployment

Every push to `main` branch automatically deploys to GitHub Pages via GitHub Actions.

## Current Infrastructure (Kubernetes)

The following services remain on the Kubernetes cluster (46.62.223.198):

- **ArgoCD**: https://argo.theedgestory.org
- **Core Pipeline Dev**: https://core-pipeline-dev.theedgestory.org
- **Core Pipeline Prod**: https://core-pipeline.theedgestory.org
- **Grafana**: https://grafana.theedgestory.org
- **Kafka UI**: https://kafka.theedgestory.org
- **MinIO**: https://s3-admin.theedgestory.org
- **Status**: https://status.theedgestory.org

These all use Cloudflare DNS pointing to 46.62.223.198.
