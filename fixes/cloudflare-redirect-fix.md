# Cloudflare Redirect Loop Fix

## Issue
All services (auth.theedgestory.org, argo.theedgestory.org, kafka.theedgestory.org) are experiencing redirect loops with HTTP 308 responses from Cloudflare.

## Root Cause
Cloudflare is issuing HTTP 308 Permanent Redirects at the edge before traffic reaches the origin server. This is typically caused by:

1. **SSL/TLS Mode**: Cloudflare is likely set to "Flexible" or has "Always Use HTTPS" enabled
2. **Page Rules**: There might be a Page Rule forcing HTTPS redirects
3. **HSTS Headers**: Cloudflare might be adding HSTS headers

## Solution

### Option 1: Fix via Cloudflare Dashboard (Recommended)

1. Log into Cloudflare Dashboard
2. Go to your domain (theedgestory.org)
3. Navigate to **SSL/TLS** → **Overview**
4. Set SSL/TLS encryption mode to **Full** (not Full Strict)
   - This allows Cloudflare to connect to origin via HTTPS without validating certificates
5. Navigate to **SSL/TLS** → **Edge Certificates**
6. **Disable** "Always Use HTTPS" if enabled
7. Navigate to **Rules** → **Page Rules**
8. Check for any rules forcing HTTPS redirects on *.theedgestory.org
9. Disable or modify those rules

### Option 2: Bypass Cloudflare Proxy (Quick Fix)

1. In Cloudflare DNS settings, set these records to **DNS Only** (grey cloud):
   - auth.theedgestory.org
   - argo.theedgestory.org
   - kafka.theedgestory.org

This will bypass Cloudflare's proxy entirely and connect directly to your server.

### Option 3: Use Cloudflare Tunnel (Already Configured)

Since cloudflared tunnel is already running, you can configure these services to use the tunnel instead:

```bash
# Update tunnel configuration
cloudflared tunnel route dns 6c01bbbf-3488-4182-b17b-3ac004a02d99 auth.theedgestory.org
cloudflared tunnel route dns 6c01bbbf-3488-4182-b17b-3ac004a02d99 argo.theedgestory.org
cloudflared tunnel route dns 6c01bbbf-3488-4182-b17b-3ac004a02d99 kafka.theedgestory.org
```

## Current Configuration

### Kubernetes Ingress
- All ingresses have `ssl-redirect: "false"` and `force-ssl-redirect: "false"`
- Proper X-Forwarded headers are configured
- Backend protocols are correctly set

### Authentik
- Configured to trust proxy headers
- Using HTTPS in AUTHENTIK_HOST
- Cookie domain set correctly

### ArgoCD
- Running in insecure mode (TLS handled by ingress)
- GRPC-Web enabled for HTTP backend

## Testing

After making Cloudflare changes:

```bash
# Test each service
curl -I https://auth.theedgestory.org
curl -I https://argo.theedgestory.org
curl -I https://kafka.theedgestory.org

# Should see HTTP/2 200 or 302 (not 308)
```

## Alternative: Direct IP Access

For testing, you can bypass Cloudflare entirely:

```bash
# Add to /etc/hosts
46.62.223.198 auth.theedgestory.org
46.62.223.198 argo.theedgestory.org
46.62.223.198 kafka.theedgestory.org

# Then access services directly
```