#!/bin/bash
# Production Setup Script for The Edge Story Infrastructure
# This script bootstraps a complete Kubernetes infrastructure from scratch

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== The Edge Story Infrastructure Setup ===${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}helm is required but not installed.${NC}" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo -e "${RED}git is required but not installed.${NC}" >&2; exit 1; }

# Configuration
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"
ADMIN_EMAIL="${ADMIN_EMAIL:-dcversus@gmail.com}"
DOMAIN="${DOMAIN:-theedgestory.org}"

# Prompt for required secrets if not set
if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo -e "${YELLOW}Google OAuth credentials required for SSO${NC}"
    echo "Get these from: https://console.cloud.google.com"
    echo ""
    read -p "Enter Google OAuth Client ID: " GOOGLE_CLIENT_ID
    read -s -p "Enter Google OAuth Client Secret: " GOOGLE_CLIENT_SECRET
    echo ""
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  Domain: $DOMAIN"
echo "  Admin Email: $ADMIN_EMAIL"
echo "  Google OAuth: Configured"
echo ""

# Install K3s if not present
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing K3s...${NC}"
    curl -sfL https://get.k3s.io | sh -
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
fi

# Install ArgoCD
echo -e "${YELLOW}Installing ArgoCD...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD
echo -e "${YELLOW}Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Install cert-manager
echo -e "${YELLOW}Installing cert-manager...${NC}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager

# Create namespaces
echo -e "${YELLOW}Creating namespaces...${NC}"
for ns in infrastructure dev-core prod-core monitoring authentik; do
    kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
done

# Deploy Authentik with stable password
echo -e "${YELLOW}Deploying Authentik SSO...${NC}"
AUTHENTIK_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic authentik-postgresql \
    --from-literal=password="$AUTHENTIK_PASSWORD" \
    -n authentik --dry-run=client -o yaml | kubectl apply -f -

# Store password in PostgreSQL
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: setup-config
  namespace: default
data:
  authentik_db_password: "$AUTHENTIK_PASSWORD"
  google_client_id: "$GOOGLE_CLIENT_ID"
  google_client_secret: "$GOOGLE_CLIENT_SECRET"
  admin_email: "$ADMIN_EMAIL"
EOF

# Deploy infrastructure applications via ArgoCD
echo -e "${YELLOW}Deploying infrastructure via ArgoCD...${NC}"
kubectl apply -f argocd-apps/

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n infrastructure --timeout=300s || true

# Configure PostgreSQL for Authentik
echo -e "${YELLOW}Configuring PostgreSQL...${NC}"
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres << EOF
CREATE USER authentik_user WITH PASSWORD '$AUTHENTIK_PASSWORD';
CREATE DATABASE authentik OWNER authentik_user;
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik_user;
EOF

# Deploy Authentik
echo -e "${YELLOW}Deploying Authentik...${NC}"
helm repo add authentik https://charts.goauthentik.io
helm repo update
helm install authentik authentik/authentik \
    --namespace authentik \
    --set authentik.secret_key="$(openssl rand -base64 32)" \
    --set authentik.error_reporting.enabled=false \
    --set postgresql.enabled=false \
    --set redis.enabled=false \
    --set authentik.postgresql.host=postgresql.infrastructure.svc.cluster.local \
    --set authentik.postgresql.name=authentik \
    --set authentik.postgresql.user=authentik_user \
    --set authentik.postgresql.password="$AUTHENTIK_PASSWORD" \
    --set authentik.redis.host=redis-master.infrastructure.svc.cluster.local \
    --set server.ingress.enabled=true \
    --set server.ingress.hosts[0]=auth.$DOMAIN \
    --set server.ingress.tls[0].secretName=authentik-tls \
    --set server.ingress.tls[0].hosts[0]=auth.$DOMAIN

# Wait for Authentik
echo -e "${YELLOW}Waiting for Authentik to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=authentik -n authentik --timeout=300s

# Configure Google OAuth in Authentik
echo -e "${YELLOW}Configuring Google OAuth...${NC}"
kubectl exec -n authentik deployment/authentik-server -- python << EOF
import os, django
os.environ['DJANGO_SETTINGS_MODULE'] = 'authentik.root.settings'
django.setup()
from authentik.sources.oauth.models import OAuthSource
from authentik.policies.expression.models import ExpressionPolicy

# Create Google OAuth source
OAuthSource.objects.update_or_create(
    slug='google',
    defaults={
        'name': 'Google',
        'provider_type': 'google',
        'consumer_key': '$GOOGLE_CLIENT_ID',
        'consumer_secret': '$GOOGLE_CLIENT_SECRET',
        'enabled': True,
        'user_matching_mode': 'email_deny'
    }
)

# Create access restriction policy
ExpressionPolicy.objects.update_or_create(
    name='Only Admin',
    defaults={
        'expression': 'return request.user.email == "$ADMIN_EMAIL"'
    }
)
print('OAuth configured successfully')
EOF

# Get ArgoCD admin password
echo -e "${YELLOW}Getting ArgoCD admin password...${NC}"
ARGO_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Summary
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo -e "${GREEN}Service URLs:${NC}"
echo "  ArgoCD: https://argo.$DOMAIN"
echo "    Username: admin"
echo "    Password: $ARGO_PASS"
echo ""
echo "  Authentik: https://auth.$DOMAIN"
echo "    Username: akadmin"
echo "    Password: (check kubectl logs)"
echo ""
echo "  Core Pipeline Prod: https://core-pipeline.$DOMAIN"
echo "  Core Pipeline Dev: https://core-pipeline.dev.$DOMAIN"
echo "  Grafana: https://grafana.dev.$DOMAIN"
echo "  Status Page: https://status.$DOMAIN"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Add this redirect URI to Google Cloud Console:"
echo "   https://auth.$DOMAIN/source/oauth/callback/google/"
echo ""
echo "2. Configure applications to use Authentik OAuth"
echo "3. Run ./scripts/healthcheck.sh to verify all services"
echo ""