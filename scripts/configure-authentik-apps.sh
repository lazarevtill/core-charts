#!/bin/bash
# Configure OAuth2/OIDC applications in Authentik for all services
# Each service gets proper RBAC policies applied

set -e

echo "🔐 Configuring Authentik OAuth applications with RBAC..."

# Configure all OAuth apps in Authentik with proper RBAC
kubectl exec -n authentik deployment/authentik-server -- python << 'EOF'
import os, django, secrets
os.environ['DJANGO_SETTINGS_MODULE'] = 'authentik.root.settings'
django.setup()

from django.contrib.auth.models import Group
from authentik.providers.oauth2.models import OAuth2Provider, ClientTypes
from authentik.core.models import Application
from authentik.flows.models import Flow
from authentik.policies.models import PolicyBinding
from authentik.policies.expression.models import ExpressionPolicy

# Get flows
authz_flow = Flow.objects.filter(designation='authorization').first()
if not authz_flow:
    print("❌ Authorization flow not found!")
    exit(1)

# Get groups
admin_group = Group.objects.get(name='administrators')
viewer_group = Group.objects.get(name='viewers')

# Get or create policies
admin_policy, _ = ExpressionPolicy.objects.update_or_create(
    name='Administrators Only',
    defaults={
        'expression': 'return "administrators" in [g.name for g in request.user.groups.all()]'
    }
)

viewer_policy, _ = ExpressionPolicy.objects.update_or_create(
    name='Viewers and Admins',
    defaults={
        'expression': 'return "viewers" in [g.name for g in request.user.groups.all()] or "administrators" in [g.name for g in request.user.groups.all()]'
    }
)

print("=== Creating OAuth2 Applications ===\n")

# ArgoCD - Admin only (can deploy)
print("Configuring ArgoCD (Admin only)...")
argocd_secret = secrets.token_urlsafe(40)
argocd_provider, _ = OAuth2Provider.objects.update_or_create(
    client_id='argocd',
    defaults={
        'name': 'ArgoCD',
        'client_secret': argocd_secret,
        'client_type': ClientTypes.CONFIDENTIAL,
        'redirect_uris': 'https://argo.theedgestory.org/auth/callback\nhttps://argo.dev.theedgestory.org/auth/callback',
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
print(f"  ✓ ArgoCD configured (Admin only)")
print(f"    Client ID: argocd")
print(f"    Client Secret: {argocd_secret}")

# Grafana - Viewers and Admins (read metrics)
print("\nConfiguring Grafana (Viewers + Admins)...")
grafana_secret = secrets.token_urlsafe(40)
grafana_provider, _ = OAuth2Provider.objects.update_or_create(
    client_id='grafana',
    defaults={
        'name': 'Grafana',
        'client_secret': grafana_secret,
        'client_type': ClientTypes.CONFIDENTIAL,
        'redirect_uris': 'https://grafana.theedgestory.org/login/generic_oauth\nhttps://grafana.dev.theedgestory.org/login/generic_oauth',
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
print(f"  ✓ Grafana configured (Viewers + Admins)")
print(f"    Client ID: grafana")
print(f"    Client Secret: {grafana_secret}")

# Kafka UI - Admin only (can modify topics)
print("\nConfiguring Kafka UI (Admin only)...")
kafka_secret = secrets.token_urlsafe(40)
kafka_provider, _ = OAuth2Provider.objects.update_or_create(
    client_id='kafka-ui',
    defaults={
        'name': 'Kafka UI',
        'client_secret': kafka_secret,
        'client_type': ClientTypes.CONFIDENTIAL,
        'redirect_uris': 'https://kafka.theedgestory.org/login/oauth2/code/\nhttps://kafka.theedgestory.org/oauth/callback',
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
print(f"  ✓ Kafka UI configured (Admin only)")
print(f"    Client ID: kafka-ui")
print(f"    Client Secret: {kafka_secret}")

# MinIO - Admin only (can modify storage)
print("\nConfiguring MinIO (Admin only)...")
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
print(f"  ✓ MinIO configured (Admin only)")
print(f"    Client ID: minio")
print(f"    Client Secret: {minio_secret}")

print("\n=== OAuth2 Configuration Complete ===")
print("\nAccess Matrix:")
print("  • ArgoCD:    Administrators only")
print("  • Grafana:   Viewers + Administrators")
print("  • Kafka UI:  Administrators only")
print("  • MinIO:     Administrators only")
print("  • Status:    Public (no auth)")
print("  • Core API:  Public (no auth)")

print("\n=== Client Secrets (Save these!) ===")
print(f"ARGOCD_CLIENT_SECRET={argocd_secret}")
print(f"GRAFANA_CLIENT_SECRET={grafana_secret}")
print(f"KAFKA_CLIENT_SECRET={kafka_secret}")
print(f"MINIO_CLIENT_SECRET={minio_secret}")

# Create LDAP Outpost for services that need it
print("\n=== Creating LDAP Outpost (optional) ===")
from authentik.outposts.models import Outpost, OutpostType
from authentik.providers.ldap.models import LDAPProvider

try:
    ldap_provider, _ = LDAPProvider.objects.update_or_create(
        name='LDAP Provider',
        defaults={
            'base_dn': 'dc=theedgestory,dc=org',
            'search_group': admin_group,
        }
    )

    ldap_outpost, _ = Outpost.objects.update_or_create(
        name='LDAP Outpost',
        defaults={
            'type': OutpostType.LDAP,
        }
    )
    ldap_outpost.providers.add(ldap_provider)
    print("  ✓ LDAP Outpost created for legacy services")
except Exception as e:
    print(f"  ℹ LDAP Outpost creation skipped: {e}")

EOF

echo ""
echo "✅ OAuth applications configured with RBAC!"
echo ""
echo "Next: Configure each service to use ONLY Authentik authentication"