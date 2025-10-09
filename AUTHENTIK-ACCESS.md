# ✅ Authentik Admin Access Ready!

## 🔑 Recovery Link for Admin Access

Use this recovery link to access Authentik as the admin user:

**Recovery URL**:
```
https://auth.theedgestory.org/recovery/use-token/WXEQiagFh0raqMOzqzRCQdIIxrBJHnpAKTBEO6Q5mdT1a5Lcu6BJVscvNFGH/
```

**⚠️ IMPORTANT**: This link provides full admin access. Keep it secure!

## 📋 What to Do Next

1. **Click the recovery link above** or paste it in your browser
2. You'll be logged in as `akadmin` automatically
3. **Set a new password** immediately:
   - Go to User Settings → Change Password
   - Set a strong password you'll remember

## 🔐 After Login - Configure SSO

Once logged in, configure Google OAuth for your account:

### Step 1: Create Google OAuth Source
1. Navigate to **Directory** → **Federation & Social login**
2. Click **Create** → **Google OAuth Source**
3. Configure:
   - Name: `Google`
   - Consumer Key: [Your Google OAuth Client ID]
   - Consumer Secret: [Your Google OAuth Secret]
   - Allowed domains: `gmail.com`

### Step 2: Link Your Email
1. Go to **Directory** → **Users**
2. Find/create user with email `dcversus@gmail.com`
3. Link to Google OAuth source

### Step 3: Set Up LDAP Outpost (for other services)
1. Navigate to **Outposts** → **Outposts**
2. Click **Create** → **LDAP Outpost**
3. Configure for service authentication

## 🚀 Quick Access Links

After setting up:
- **Authentik Admin**: https://auth.theedgestory.org/if/admin/
- **User Interface**: https://auth.theedgestory.org/if/user/
- **Login Page**: https://auth.theedgestory.org/

## 📝 Service Integration

Run the helper script after configuring Google OAuth:
```bash
bash scripts/configure-authentik-sso.sh
```

This will guide you through integrating:
- ArgoCD
- Grafana
- Kafka UI
- MinIO

## 🔒 Security Note

After using the recovery link:
1. Change the admin password immediately
2. Enable 2FA/MFA for admin account
3. Restrict access to only dcversus@gmail.com