#!/bin/bash
# Complete Authentik setup with groups, policies, and OAuth providers

set -e

echo "🔐 Setting up Authentik with complete OAuth configuration..."
echo ""

kubectl exec -n authentik deployment/authentik-server -- python3 << 'EOF'
import os, django, secrets
os.environ['DJANGO_SETTINGS_MODULE'] = 'authentik.root.settings'
django.setup()

from django.contrib.auth.models import Group
from authentik.providers.oauth2.models import OAuth2Provider, ClientTypes
from authentik.core.models import Application, User
from authentik.flows.models import Flow
from authentik.policies.models import PolicyBinding
from authentik.policies.expression.models import ExpressionPolicy

print("=== Step 1: Creating Groups ===\n")

# Create groups
admin_group, created = Group.objects.get_or_create(name='administrators')
print(f"  {'✓ Created' if created else '✓ Found'} administrators group")

viewer_group, created = Group.objects.get_or_create(name='viewers')
print(f"  {'✓ Created' if created else '✓ Found'} viewers group")

# Add akadmin to administrators group
try:
    akadmin = User.objects.get(username='akadmin')
    akadmin.groups.add(admin_group)
    print(f"  ✓ Added akadmin to administrators group")
except User.DoesNotExist:
    print(f"  ℹ akadmin user not found")

print("\n=== Step 2: Creating Access Policies ===\n")

# Get authorization flow
authz_flow = Flow.objects.filter(designation='authorization').first()
if not authz_flow:
    print("❌ Authorization flow not found!")
    exit(1)
print(f"  ✓ Found authorization flow: {authz_flow.name}")

# Create policies
admin_policy, created = ExpressionPolicy.objects.update_or_create(
    name='Administrators Only',
    defaults={
        'expression': 'return ak_is_group_member(request.user, name="administrators")'
    }
)
print(f"  {'✓ Created' if created else '✓ Updated'} Administrators Only policy")

viewer_policy, created = ExpressionPolicy.objects.update_or_create(
    name='Viewers and Admins',
    defaults={
        'expression': 'return ak_is_group_member(request.user, name="viewers") or ak_is_group_member(request.user, name="administrators")'
    }
)
print(f"  {'✓ Created' if created else '✓ Updated'} Viewers and Admins policy")

print("\n=== Step 3: Creating OAuth2 Providers ===\n")

# Store secrets for output
secrets_output = {}

# ArgoCD - Admin only
print("Creating ArgoCD provider...")
argocd_secret = secrets.token_urlsafe(40)
argocd_provider, _ = OAuth2Provider.objects.update_or_create(
    client_id='argocd',
    defaults={
        'name': 'ArgoCD',
        'client_secret': argocd_secret,
        'client_type': ClientTypes.CONFIDENTIAL,
        'redirect_uris': 'https://argo.theedgestory.org/auth/callback\nhttps://argo.theedgestory.org/api/dex/callback',
        'authorization_flow': authz_flow,
        'sub_mode': 'hashed_user_id',
        'include_claims_in_id_token': True,
    }
)
argocd_app, _ = Application.objects.update_or_create(
    slug='argocd',
    defaults={
        'name': 'ArgoCD',
        'provider': argocd_provider,
        'meta_launch_url': 'https://argo.theedgestory.org',
    }
)
PolicyBinding.objects.filter(target=argocd_app).delete()
PolicyBinding.objects.create(policy=admin_policy, target=argocd_app, order=0)
secrets_output['argocd'] = argocd_secret
print(f"  ✓ ArgoCD configured (Administrators only)")

# Grafana - Viewers and Admins
print("Creating Grafana provider...")
grafana_secret = secrets.token_urlsafe(40)
grafana_provider, _ = OAuth2Provider.objects.update_or_create(
    client_id='grafana',
    defaults={
        'name': 'Grafana',
        'client_secret': grafana_secret,
        'client_type': ClientTypes.CONFIDENTIAL,
        'redirect_uris': 'https://grafana.theedgestory.org/login/generic_oauth',
        'authorization_flow': authz_flow,
        'sub_mode': 'hashed_user_id',
        'include_claims_in_id_token': True,
    }
)
grafana_app, _ = Application.objects.update_or_create(
    slug='grafana',
    defaults={
        'name': 'Grafana',
        'provider': grafana_provider,
        'meta_launch_url': 'https://grafana.theedgestory.org',
    }
)
PolicyBinding.objects.filter(target=grafana_app).delete()
PolicyBinding.objects.create(policy=viewer_policy, target=grafana_app, order=0)
secrets_output['grafana'] = grafana_secret
print(f"  ✓ Grafana configured (Viewers + Administrators)")

# Kafka UI - Admin only
print("Creating Kafka UI provider...")
kafka_secret = secrets.token_urlsafe(40)
kafka_provider, _ = OAuth2Provider.objects.update_or_create(
    client_id='kafka-ui',
    defaults={
        'name': 'Kafka UI',
        'client_secret': kafka_secret,
        'client_type': ClientTypes.CONFIDENTIAL,
        'redirect_uris': 'https://kafka.theedgestory.org/login/oauth2/code/authentik',
        'authorization_flow': authz_flow,
        'sub_mode': 'hashed_user_id',
        'include_claims_in_id_token': True,
    }
)
kafka_app, _ = Application.objects.update_or_create(
    slug='kafka-ui',
    defaults={
        'name': 'Kafka UI',
        'provider': kafka_provider,
        'meta_launch_url': 'https://kafka.theedgestory.org',
    }
)
PolicyBinding.objects.filter(target=kafka_app).delete()
PolicyBinding.objects.create(policy=admin_policy, target=kafka_app, order=0)
secrets_output['kafka'] = kafka_secret
print(f"  ✓ Kafka UI configured (Administrators only)")

# MinIO - Admin only
print("Creating MinIO provider...")
minio_secret = secrets.token_urlsafe(40)
minio_provider, _ = OAuth2Provider.objects.update_or_create(
    client_id='minio',
    defaults={
        'name': 'MinIO',
        'client_secret': minio_secret,
        'client_type': ClientTypes.CONFIDENTIAL,
        'redirect_uris': 'https://s3-admin.theedgestory.org/oauth_callback',
        'authorization_flow': authz_flow,
        'sub_mode': 'hashed_user_id',
        'include_claims_in_id_token': True,
    }
)
minio_app, _ = Application.objects.update_or_create(
    slug='minio',
    defaults={
        'name': 'MinIO Console',
        'provider': minio_provider,
        'meta_launch_url': 'https://s3-admin.theedgestory.org',
    }
)
PolicyBinding.objects.filter(target=minio_app).delete()
PolicyBinding.objects.create(policy=admin_policy, target=minio_app, order=0)
secrets_output['minio'] = minio_secret
print(f"  ✓ MinIO configured (Administrators only)")

print("\n=== Configuration Complete! ===\n")
print("OAuth2 Client Credentials:")
print(f"  ArgoCD:    client_id=argocd       secret={secrets_output['argocd']}")
print(f"  Grafana:   client_id=grafana      secret={secrets_output['grafana']}")
print(f"  Kafka UI:  client_id=kafka-ui     secret={secrets_output['kafka']}")
print(f"  MinIO:     client_id=minio        secret={secrets_output['minio']}")

print("\nOIDC Endpoints:")
print("  Issuer:        https://auth.theedgestory.org/application/o/<client_id>/")
print("  Authorization: https://auth.theedgestory.org/application/o/authorize/")
print("  Token:         https://auth.theedgestory.org/application/o/token/")
print("  UserInfo:      https://auth.theedgestory.org/application/o/userinfo/")
print("  JWKS:          https://auth.theedgestory.org/application/o/<client_id>/jwks/")

print("\nAccess Control:")
print("  ArgoCD:    Administrators only")
print("  Grafana:   Viewers + Administrators")
print("  Kafka UI:  Administrators only")
print("  MinIO:     Administrators only")
EOF

echo ""
echo "✅ Authentik OAuth configuration complete!"
echo ""
echo "Next steps:"
echo "  1. Save the client secrets above"
echo "  2. Configure each service with its OAuth credentials"
echo "  3. Test authentication for each service"
