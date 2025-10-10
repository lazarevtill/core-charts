#!/bin/bash
# Setup Script - Complete infrastructure setup from scratch

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Core Charts Infrastructure Setup ===${NC}"
echo ""

# Check required environment variables
if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ] || [ -z "$ADMIN_EMAIL" ]; then
    echo -e "${RED}Error: Required environment variables not set${NC}"
    echo "Please set:"
    echo "  export GOOGLE_CLIENT_ID='your-client-id'"
    echo "  export GOOGLE_CLIENT_SECRET='your-client-secret'"
    echo "  export ADMIN_EMAIL='your-email@gmail.com'"
    exit 1
fi

# Check K3s is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Installing K3s...${NC}"
    curl -sfL https://get.k3s.io | sh -
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

echo -e "${YELLOW}Step 1: Installing ArgoCD...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo -e "${YELLOW}Step 2: Installing cert-manager...${NC}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

echo -e "${YELLOW}Step 3: Creating namespaces...${NC}"
for ns in infrastructure dev-core prod-core monitoring authentik; do
    kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
done

echo -e "${YELLOW}Step 4: Applying ArgoCD applications...${NC}"
kubectl apply -f argocd-apps/

echo -e "${YELLOW}Step 5: Waiting for infrastructure...${NC}"
sleep 60
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=postgresql -n infrastructure || true
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=redis -n infrastructure || true

echo -e "${YELLOW}Step 6: Setting up Authentik...${NC}"
# Fixed PostgreSQL password for Authentik
AUTHENTIK_DB_PASSWORD="WNAkt8ZouZRhvlcf3HSAxFXQfbt4qszs"

# Create PostgreSQL database for Authentik
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -c "CREATE USER authentik_user WITH PASSWORD '$AUTHENTIK_DB_PASSWORD';" || true
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -c "CREATE DATABASE authentik OWNER authentik_user;" || true
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik_user;" || true
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -c "ALTER USER authentik_user WITH PASSWORD '$AUTHENTIK_DB_PASSWORD';" || true

# Create secret for Authentik
kubectl create secret generic authentik-postgresql \
    --from-literal=password="$AUTHENTIK_DB_PASSWORD" \
    -n authentik --dry-run=client -o yaml | kubectl apply -f -

# Deploy Authentik using Helm
helm repo add authentik https://charts.goauthentik.io || true
helm repo update
helm upgrade --install authentik authentik/authentik \
    --namespace authentik \
    --set authentik.secret_key="$(openssl rand -base64 32)" \
    --set authentik.error_reporting.enabled=false \
    --set postgresql.enabled=false \
    --set redis.enabled=false \
    --set authentik.postgresql.host=postgresql.infrastructure.svc.cluster.local \
    --set authentik.postgresql.name=authentik \
    --set authentik.postgresql.user=authentik_user \
    --set authentik.postgresql.password="$AUTHENTIK_DB_PASSWORD" \
    --set authentik.redis.host=redis.infrastructure.svc.cluster.local \
    --set server.ingress.enabled=true \
    --set server.ingress.hosts[0]=auth.theedgestory.org \
    --set server.ingress.className=nginx \
    --set server.ingress.tls[0].secretName=authentik-tls \
    --set server.ingress.tls[0].hosts[0]=auth.theedgestory.org \
    --wait --timeout=5m

echo -e "${YELLOW}Step 7: Configuring Google OAuth...${NC}"
# Wait for Authentik to be ready
sleep 30
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=authentik-server -n authentik || true

# Configure Google OAuth
kubectl exec -n authentik deployment/authentik-server -- python << EOF 2>/dev/null || true
import os, django
os.environ['DJANGO_SETTINGS_MODULE'] = 'authentik.root.settings'
django.setup()

from authentik.sources.oauth.models import OAuthSource
from authentik.policies.expression.models import ExpressionPolicy
from authentik.flows.models import Flow

# Create Google OAuth source
google_source, _ = OAuthSource.objects.update_or_create(
    slug='google',
    defaults={
        'name': 'Google',
        'provider_type': 'google',
        'consumer_key': '$GOOGLE_CLIENT_ID',
        'consumer_secret': '$GOOGLE_CLIENT_SECRET',
        'enabled': True,
        'user_matching_mode': 'email_deny',
        'enrollment_flow': Flow.objects.filter(designation='enrollment').first(),
        'authentication_flow': Flow.objects.filter(designation='authentication').first(),
    }
)

# Create access policy
policy, _ = ExpressionPolicy.objects.get_or_create(
    name='Only $ADMIN_EMAIL',
    defaults={'expression': 'return request.user.email == "$ADMIN_EMAIL"'}
)

print('Google OAuth configured successfully')
EOF

echo -e "${YELLOW}Step 8: Configuring OAuth applications...${NC}"
./scripts/configure-authentik-apps.sh

echo -e "${YELLOW}Step 9: Final sync of all applications...${NC}"
for app in $(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}'); do
    kubectl patch application $app -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}' || true
done

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Access points:"
echo "  • Authentik SSO: https://auth.theedgestory.org"
echo "  • ArgoCD: https://argo.theedgestory.org (login via Authentik)"
echo "  • Grafana: https://grafana.theedgestory.org (login via Authentik)"
echo "  • Kafka UI: https://kafka.theedgestory.org (login via Authentik)"
echo "  • MinIO: https://s3-admin.theedgestory.org (login via Authentik)"
echo "  • Status Page: https://status.theedgestory.org (public)"
echo "  • Core Pipeline: https://core-pipeline.theedgestory.org (public API)"
echo ""
echo "Login with your Google account: $ADMIN_EMAIL"
echo ""
echo "Run ./scripts/healthcheck.sh to verify all services"