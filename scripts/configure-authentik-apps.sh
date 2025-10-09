#!/bin/bash
# Configure all applications in Authentik for SSO

set -e

echo "Configuring Authentik OAuth applications..."

# Configure all OAuth apps in Authentik
kubectl exec -n authentik deployment/authentik-server -- python << 'EOF'
import os, django, secrets
os.environ['DJANGO_SETTINGS_MODULE'] = 'authentik.root.settings'
django.setup()

from authentik.providers.oauth2.models import OAuth2Provider, ClientTypes, ResponseTypes
from authentik.core.models import Application
from authentik.flows.models import Flow
from authentik.policies.models import PolicyBinding
from authentik.policies.expression.models import ExpressionPolicy

# Get flows
auth_flow = Flow.objects.filter(designation='authentication').first()
authz_flow = Flow.objects.filter(designation='authorization').first()

# Get or create access policy
policy, _ = ExpressionPolicy.objects.get_or_create(
    name='Only dcversus',
    defaults={'expression': 'return request.user.email == "dcversus@gmail.com"'}
)

# ArgoCD Application
print("Configuring ArgoCD...")
argocd_provider, _ = OAuth2Provider.objects.update_or_create(
    name='ArgoCD',
    defaults={
        'client_id': 'argocd',
        'client_secret': secrets.token_urlsafe(40),
        'client_type': ClientTypes.CONFIDENTIAL,
        'response_type': ResponseTypes.CODE,
        'redirect_uris': 'https://argo.theedgestory.org/auth/callback\nhttps://argo.dev.theedgestory.org/auth/callback',
        'authorization_flow': authz_flow,
        'signing_key': None,
        'sub_mode': 'hashed_user_id',
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
PolicyBinding.objects.get_or_create(policy=policy, target=argocd_app, order=0)

# Grafana Application
print("Configuring Grafana...")
grafana_provider, _ = OAuth2Provider.objects.update_or_create(
    name='Grafana',
    defaults={
        'client_id': 'grafana',
        'client_secret': secrets.token_urlsafe(40),
        'client_type': ClientTypes.CONFIDENTIAL,
        'response_type': ResponseTypes.CODE,
        'redirect_uris': 'https://grafana.dev.theedgestory.org/login/generic_oauth',
        'authorization_flow': authz_flow,
        'signing_key': None,
        'sub_mode': 'hashed_user_id',
    }
)
grafana_app, _ = Application.objects.update_or_create(
    slug='grafana',
    defaults={
        'name': 'Grafana',
        'provider': grafana_provider,
        'meta_launch_url': 'https://grafana.dev.theedgestory.org',
    }
)
PolicyBinding.objects.get_or_create(policy=policy, target=grafana_app, order=0)

# Kafka UI Application
print("Configuring Kafka UI...")
kafka_provider, _ = OAuth2Provider.objects.update_or_create(
    name='Kafka UI',
    defaults={
        'client_id': 'kafka-ui',
        'client_secret': secrets.token_urlsafe(40),
        'client_type': ClientTypes.CONFIDENTIAL,
        'response_type': ResponseTypes.CODE,
        'redirect_uris': 'https://kafka.theedgestory.org/oauth/callback',
        'authorization_flow': authz_flow,
        'signing_key': None,
        'sub_mode': 'hashed_user_id',
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
PolicyBinding.objects.get_or_create(policy=policy, target=kafka_app, order=0)

# Print credentials for configuration
print("\n=== OAuth Credentials ===")
print(f"ArgoCD Client Secret: {argocd_provider.client_secret}")
print(f"Grafana Client Secret: {grafana_provider.client_secret}")
print(f"Kafka UI Client Secret: {kafka_provider.client_secret}")
print("\nSave these secrets to configure the applications!")
EOF

echo ""
echo "OAuth applications configured in Authentik!"
echo "Use the client secrets above to configure each application."