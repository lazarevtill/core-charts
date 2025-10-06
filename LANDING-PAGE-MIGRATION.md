# Landing Page Migration to GitHub Pages

## ✅ Complete Package Ready

The landing page repository is ready at `/tmp/theedgestory.org/` and packaged at `~/theedgestory-org-repo.tar.gz`

## Steps to Create GitHub Repository

### 1. Create New GitHub Repository

Go to https://github.com/new and create:
- **Repository name**: `theedgestory.org`
- **Description**: "Official landing page for The Edge Story - Endless Cosmic Narrative"
- **Visibility**: Public
- **DO NOT** initialize with README (we have our own)

### 2. Push the Landing Page

```bash
cd /tmp/theedgestory.org
git init
git add .
git commit -m "feat: initial landing page for The Edge Story

- Responsive cosmic-themed landing page
- Privacy Policy (GDPR compliant)
- Terms of Service with IP ownership
- GitHub Actions auto-deployment to GitHub Pages
- Custom domain configuration (theedgestory.org)
"
git branch -M main
git remote add origin https://github.com/uz0/theedgestory.org.git
git push -u origin main
```

### 3. Enable GitHub Pages

1. Go to https://github.com/uz0/theedgestory.org/settings/pages
2. **Source**: Deploy from a branch
3. **Branch**: `main` / `/(root)`
4. Click **Save**
5. Under **Custom domain**, enter: `theedgestory.org`
6. Check **Enforce HTTPS**

### 4. Configure DNS Records

Add these DNS records (see `DNS-SETUP.md` for details):

**A Records** (for theedgestory.org):
```
185.199.108.153
185.199.109.153
185.199.110.153  
185.199.111.153
```

**CNAME Record** (for www):
```
www → uz0.github.io
```

### 5. Verify Deployment

After GitHub Actions completes (~2-3 minutes):
- https://uz0.github.io/theedgestory.org (immediate)
- https://theedgestory.org (after DNS propagation, 5-60 minutes)

## Files Included

```
theedgestory.org/
├── .github/workflows/
│   └── deploy.yml          # Auto-deploy on push to main
├── .gitignore
├── CNAME                   # Custom domain: theedgestory.org
├── README.md               # Repository documentation
├── index.html              # Main landing page (cosmic theme)
├── privacy-policy.html     # GDPR-compliant privacy policy
└── terms-of-service.html   # Terms with IP ownership clause
```

## What Happens Next

1. **Every push to `main`** triggers GitHub Actions
2. **GitHub Pages** builds and deploys automatically
3. **DNS records** route traffic to GitHub Pages
4. **Let's Encrypt** SSL certificate auto-provisioned by GitHub

## Cleanup (After Successful Migration)

Once https://theedgestory.org works on GitHub Pages, update core-charts:

```bash
# Remove landing page from Kubernetes
kubectl delete application landing-page -n argocd
kubectl delete -f landing/deploy-landing.yaml

# Remove landing directory from core-charts repo
rm -rf landing/
git add landing/
git commit -m "chore: remove landing page (migrated to GitHub Pages)"
git push origin main
```
