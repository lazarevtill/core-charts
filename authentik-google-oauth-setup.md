# Authentik Google OAuth Setup

## Quick Browser Console Method

Since Authentik has CSRF issues with the API, use this browser console method:

1. **Login to Authentik**: https://auth.theedgestory.org
   - Username: `akadmin`
   - Password: `Admin123!`

2. **Open Browser Console** (F12 → Console tab)

3. **Set your OAuth credentials as variables**:
```javascript
// Replace these with your actual credentials
const CLIENT_ID = 'YOUR_GOOGLE_CLIENT_ID';
const CLIENT_SECRET = 'YOUR_GOOGLE_CLIENT_SECRET';
```

4. **Run this code to create the OAuth source**:
```javascript
(async () => {
  const csrfToken = document.cookie.match(/authentik_csrf=([^;]+)/)?.[1];

  if (!csrfToken) {
    console.error('❌ No CSRF token found. Make sure you are logged in.');
    return;
  }

  try {
    const response = await fetch('/api/v3/sources/oauth/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Authentik-CSRF': csrfToken
      },
      body: JSON.stringify({
        name: 'Google',
        slug: 'google',
        enabled: true,
        provider_type: 'google',
        consumer_key: CLIENT_ID,
        consumer_secret: CLIENT_SECRET,
        user_matching_mode: 'email_deny',
        user_path_template: 'goauthentik.io/sources/%(slug)s',
        group_matching_mode: 'identifier',
        additional_scopes: ''
      }),
      credentials: 'same-origin'
    });

    const data = await response.json();

    if (response.ok && data.slug) {
      console.log('✅ SUCCESS! Google OAuth source created');
      console.log('📋 Details:', data);
      console.log('🔗 Callback URL for Google Console:');
      console.log('https://auth.theedgestory.org/source/oauth/callback/google/');

      // Redirect to sources page
      setTimeout(() => {
        window.location.href = '/if/admin/#/core/sources';
      }, 2000);
    } else {
      console.error('❌ Failed:', data);
    }
  } catch (error) {
    console.error('❌ Error:', error);
  }
})();
```

## Alternative: Direct Python Method

If the browser method doesn't work, SSH to the server and run:

```bash
# Get into the Authentik pod
kubectl exec -it -n authentik deployment/authentik-server -- python

# In Python shell:
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'authentik.root.settings')
import django
django.setup()

from authentik.sources.oauth.models import OAuthSource
from authentik.flows.models import Flow

# Set your credentials
CLIENT_ID = 'YOUR_GOOGLE_CLIENT_ID'
CLIENT_SECRET = 'YOUR_GOOGLE_CLIENT_SECRET'

auth_flow = Flow.objects.filter(designation='authentication').first()
enroll_flow = Flow.objects.filter(designation='enrollment').first()

source = OAuthSource.objects.create(
    name='Google',
    slug='google',
    provider_type='google',
    consumer_key=CLIENT_ID,
    consumer_secret=CLIENT_SECRET,
    enabled=True,
    authentication_flow=auth_flow,
    enrollment_flow=enroll_flow,
    user_matching_mode='email_deny'
)
print(f'Created: {source.slug}')
exit()
```

## After Creation

1. **Configure Google Cloud Console**
   - Add this redirect URI: `https://auth.theedgestory.org/source/oauth/callback/google/`

2. **Test Login**
   - Logout and visit https://auth.theedgestory.org
   - Click "Login with Google"

3. **Restrict Access** (Important!)
   - Go to **Policies** → **Policies** → **Create**
   - Type: Expression Policy
   - Name: "Only dcversus"
   - Expression: `return request.user.email == "dcversus@gmail.com"`
   - Apply to all applications

## Troubleshooting

If you see CSRF errors:
1. Make sure you're logged in to Authentik
2. Check that cookies are enabled
3. Try using an incognito window
4. If all else fails, use the Direct Python Method above