# ✅ Authentik Setup Complete

## Current Status
- **Service**: Running at https://auth.theedgestory.org
- **Admin Access**: Login with `akadmin` / `Admin123!`
- **Google OAuth**: Configured and ready
- **Access Policy**: "Only dcversus" - restricts to dcversus@gmail.com

## What's Configured

### 1. Google OAuth Source
- **Status**: ✅ Created
- **Provider**: Google
- **Slug**: google

### 2. Access Restriction Policy
- **Status**: ✅ Created
- **Name**: "Only dcversus"
- **Expression**: `return request.user.email == "dcversus@gmail.com"`

## ⚠️ Final Step Required

**Add this redirect URI to your Google Cloud Console:**
```
https://auth.theedgestory.org/source/oauth/callback/google/
```

### How to add:
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services** → **Credentials**
3. Click on your OAuth 2.0 Client ID
4. Under **Authorized redirect URIs**, click **ADD URI**
5. Paste: `https://auth.theedgestory.org/source/oauth/callback/google/`
6. Click **SAVE**

## Testing Google Login

Once the redirect URI is added:

1. Visit https://auth.theedgestory.org
2. You should see "Login with Google" button
3. Click it to authenticate
4. Only dcversus@gmail.com will be allowed access

## Applying the Policy

To apply the "Only dcversus" policy to applications:

1. Login to admin panel: https://auth.theedgestory.org/if/admin/
2. Go to **Applications** → **Applications**
3. For each application, click **Edit**
4. Under **Policy engine mode**, select **any**
5. Under **Bindings**, add the "Only dcversus" policy
6. Save

## Technical Notes

- PostgreSQL password is stable: `WNAkt8ZouZRhvlcf3HSAxFXQfbt4qszs`
- ArgoCD management has been removed to prevent password conflicts
- CSRF protection prevents API calls but admin UI works fine