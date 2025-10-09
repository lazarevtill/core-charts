#!/bin/bash
# Automated Authentik Google OAuth Setup
# This script creates the OAuth source directly in the running Authentik instance

set -e

echo "🔐 Setting up Google OAuth in Authentik..."
echo ""
echo "This script will:"
echo "1. Connect to the running Authentik pod"
echo "2. Create a Google OAuth source using your credentials"
echo "3. Configure it for single sign-on"
echo ""

# Check if credentials are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <GOOGLE_CLIENT_ID> <GOOGLE_CLIENT_SECRET>"
    echo ""
    echo "Example:"
    echo "  $0 501843646349-xxx.apps.googleusercontent.com GOCSPX-xxxxx"
    exit 1
fi

CLIENT_ID="$1"
CLIENT_SECRET="$2"

# Find Authentik pod
echo "🔍 Finding Authentik server pod..."
POD=$(kubectl get pods -n authentik -l app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD" ]; then
    echo "❌ No Authentik server pod found"
    echo "   Make sure Authentik is deployed in the 'authentik' namespace"
    exit 1
fi

echo "✅ Found pod: $POD"
echo ""

# Create Python script to run inside pod
cat > /tmp/create-oauth.py << 'EOF'
import os
import sys

# Django setup
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'authentik.root.settings')
sys.path.insert(0, '/ak-root')

import django
django.setup()

from authentik.sources.oauth.models import OAuthSource
from authentik.flows.models import Flow

# Get credentials from environment
client_id = os.environ['OAUTH_CLIENT_ID']
client_secret = os.environ['OAUTH_CLIENT_SECRET']

# Check if already exists
existing = OAuthSource.objects.filter(slug='google').first()
if existing:
    print(f"⚠️  Google OAuth already exists, updating...")
    existing.consumer_key = client_id
    existing.consumer_secret = client_secret
    existing.enabled = True
    existing.save()
    print(f"✅ Updated Google OAuth source")
else:
    # Get flows
    auth_flow = Flow.objects.filter(designation='authentication').first()
    enroll_flow = Flow.objects.filter(designation='enrollment').first()

    # Create source
    source = OAuthSource.objects.create(
        name='Google',
        slug='google',
        provider_type='google',
        consumer_key=client_id,
        consumer_secret=client_secret,
        enabled=True,
        authentication_flow=auth_flow,
        enrollment_flow=enroll_flow,
        user_matching_mode='email_deny',
        user_path_template='goauthentik.io/sources/%(slug)s',
        group_matching_mode='identifier'
    )
    print(f"✅ Created Google OAuth source")

print("")
print("📋 Configuration complete!")
print("   Callback URL: https://auth.theedgestory.org/source/oauth/callback/google/")
EOF

# Copy and execute
echo "📦 Creating OAuth source in Authentik..."
kubectl cp /tmp/create-oauth.py authentik/$POD:/tmp/create-oauth.py

kubectl exec -n authentik $POD -- bash -c "
export OAUTH_CLIENT_ID='$CLIENT_ID'
export OAUTH_CLIENT_SECRET='$CLIENT_SECRET'
cd /ak-root && python /tmp/create-oauth.py
"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Add this redirect URI to your Google Cloud Console OAuth client:"
echo "   https://auth.theedgestory.org/source/oauth/callback/google/"
echo ""
echo "2. Test the login:"
echo "   - Go to https://auth.theedgestory.org"
echo "   - Click 'Login with Google'"
echo ""
echo "3. To restrict access to specific email:"
echo "   - Login as admin (akadmin/Admin123!)"
echo "   - Go to Policies → Create Expression Policy"
echo "   - Expression: return request.user.email == \"your-email@gmail.com\""
echo ""

# Clean up
rm -f /tmp/create-oauth.py