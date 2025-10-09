# ⚠️ ACTION REQUIRED: Fix Cloudflare Redirect Loops

## Current Issue
All services are experiencing ERR_TOO_MANY_REDIRECTS due to Cloudflare issuing HTTP 308 permanent redirects.

## Services Affected
- ❌ https://auth.theedgestory.org (Authentik)
- ❌ https://argo.theedgestory.org (ArgoCD)
- ❌ https://kafka.theedgestory.org (Kafka UI)

## Root Cause
Cloudflare is redirecting HTTP→HTTPS at the edge, but our nginx ingress is also trying to handle SSL, creating a redirect loop.

## ✅ Services Working Internally
Confirmed all services are working when accessed directly:
- Authentik: Returns HTTP 302 (auth flow redirect) ✅
- ArgoCD: Returns HTTP 200 ✅
- Kafka UI: Service running ✅

## 🔧 SOLUTION: Fix in Cloudflare Dashboard

### Step 1: Login to Cloudflare
Go to https://dash.cloudflare.com and select the `theedgestory.org` domain.

### Step 2: Change SSL/TLS Mode
1. Navigate to **SSL/TLS** → **Overview**
2. Change encryption mode from "Flexible" to **"Full"**
   - This allows Cloudflare to connect to your origin via HTTPS without strict certificate validation
   - Do NOT use "Full (strict)" as it requires valid certificates

### Step 3: Disable Always Use HTTPS
1. Navigate to **SSL/TLS** → **Edge Certificates**
2. Find "Always Use HTTPS" setting
3. **Turn it OFF** (toggle to disabled)

### Step 4: Check Page Rules
1. Navigate to **Rules** → **Page Rules**
2. Look for any rules affecting `*.theedgestory.org`
3. Disable or delete any rules that force HTTPS redirects

### Step 5: Clear Cache
1. Navigate to **Caching** → **Configuration**
2. Click "Purge Everything"
3. Confirm the cache purge

## 🚀 Alternative Quick Fix: Bypass Cloudflare Proxy

If you need immediate access while fixing Cloudflare settings:

1. Go to **DNS** → **Records**
2. Find these records:
   - `auth.theedgestory.org`
   - `argo.theedgestory.org`
   - `kafka.theedgestory.org`
3. Click the orange cloud icon to make it **gray** (DNS Only mode)
4. This bypasses Cloudflare proxy entirely

**Note**: You'll lose Cloudflare's DDoS protection and CDN benefits in DNS-only mode.

## 📝 What We've Already Fixed

### Kubernetes Side (✅ Complete)
- Configured all ingresses with proper headers
- Disabled SSL redirects at ingress level
- Set backend protocols correctly
- Added proxy header trust configuration

### Authentik Configuration (✅ Complete)
- Configured to trust X-Forwarded headers
- Set correct external URL
- Cookie domain configured

### ArgoCD Configuration (✅ Complete)
- Running in insecure mode (TLS handled externally)
- GRPC-Web enabled
- Server config updated

## 🧪 Testing After Fix

Once Cloudflare settings are updated, test with:

```bash
# Should return HTTP 200 or 302, NOT 308
curl -I https://auth.theedgestory.org
curl -I https://argo.theedgestory.org
curl -I https://kafka.theedgestory.org
```

## 📱 Local Testing (Without Cloudflare Changes)

Add to your `/etc/hosts` file:
```
46.62.223.198 auth.theedgestory.org
46.62.223.198 argo.theedgestory.org
46.62.223.198 kafka.theedgestory.org
```

Then access the services normally in your browser. They should work without redirect loops.

## 🔄 Next Steps After Fixing Redirects

Once services are accessible:
1. ✅ Access Authentik at https://auth.theedgestory.org
2. ✅ Login with initial admin credentials:
   - Email: dcversus@gmail.com
   - Password: authentik-admin-password-2024
3. ✅ Configure Google OAuth provider
4. ✅ Set up LDAP outpost
5. ✅ Migrate services to Authentik authentication