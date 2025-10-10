#!/bin/bash
# Get OAuth2 client secrets from Authentik

set -e

echo "🔑 Retrieving OAuth2 client secrets from Authentik..."
echo ""

kubectl exec -n authentik deployment/authentik-server -- python << 'EOF'
import os, django
os.environ['DJANGO_SETTINGS_MODULE'] = 'authentik.root.settings'
django.setup()

from authentik.providers.oauth2.models import OAuth2Provider
from authentik.core.models import Application

providers = OAuth2Provider.objects.all().order_by('name')

if not providers:
    print("❌ No OAuth2 providers found!")
    print("Run ./scripts/configure-authentik-apps.sh first")
    exit(1)

print("=== OAuth2 Credentials ===\n")

for provider in providers:
    app = Application.objects.filter(provider=provider).first()
    print(f"{provider.name}:")
    print(f"  Client ID:     {provider.client_id}")
    print(f"  Client Secret: {provider.client_secret}")
    print(f"  Redirect URIs: {provider.redirect_uris.replace(chr(10), ', ')}")
    if app:
        print(f"  Launch URL:    {app.meta_launch_url}")
    print()

print("\n=== OIDC Endpoints ===")
print("  Issuer URL:           https://auth.theedgestory.org/application/o/{client_id}/")
print("  Authorization URL:    https://auth.theedgestory.org/application/o/authorize/")
print("  Token URL:            https://auth.theedgestory.org/application/o/token/")
print("  UserInfo URL:         https://auth.theedgestory.org/application/o/userinfo/")
print("  JWKS URL:             https://auth.theedgestory.org/application/o/{client_id}/jwks/")
print("  Logout URL:           https://auth.theedgestory.org/application/o/{client_id}/end-session/")
EOF
