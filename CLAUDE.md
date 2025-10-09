# CLAUDE.md

Instructions for Claude Code when working with this repository.

## 🚨 CRITICAL RULES

### File Management
- ✅ **ALLOWED**: Only `CLAUDE.md` and `README.md` in root
- ❌ **FORBIDDEN**: Any other files in root directory
- ✅ **Scripts**: Only in `scripts/` directory
- ✅ **Config**: Only in designated directories

### Production Standards
1. All services must use Authentik SSO
2. Access restricted to admin email only
3. No hardcoded secrets
4. GitOps only - changes via Git
5. Test with `./scripts/healthcheck.sh`

## Current State

### ✅ Production Ready

**Infrastructure:**
- K3s + ArgoCD + Authentik SSO
- PostgreSQL, Redis, Kafka (shared)
- All services authenticated

**Authentication:**
- Authentik: https://auth.theedgestory.org
- Google OAuth configured
- Access policy: dcversus@gmail.com only
- All services integrated

## Key Information

### Authentik Credentials
- Admin: akadmin / Admin123!
- Database password: WNAkt8ZouZRhvlcf3HSAxFXQfbt4qszs
- No ArgoCD management (prevents password conflicts)

### Scripts
- `setup.sh` - Complete setup
- `deploy.sh` - Apply changes
- `healthcheck.sh` - Verify health
- `configure-authentik-apps.sh` - OAuth setup

### Common Tasks

Deploy changes:
```bash
git push origin main  # Auto-sync
./scripts/deploy.sh   # Manual
```

Check status:
```bash
./scripts/healthcheck.sh
kubectl get pods -A
```

## Troubleshooting

**503 Errors**: Usually PostgreSQL auth issue
- Check password sync
- Restart pods if needed

**OAuth Issues**: Check in Authentik admin UI
- Verify Google OAuth source exists
- Check access policy

## Important Notes

- CSRF issues in Authentik API - use UI instead
- Manual Authentik deployment (not via ArgoCD)
- All services require auth except status page
- Repository must stay clean - no temp files