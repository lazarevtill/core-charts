#!/bin/bash
# Generate secrets YAML from environment variables
# Usage:
#   export GITHUB_USERNAME="myuser"
#   export GITHUB_TOKEN="ghp_xxxxx"
#   ./generate-secrets.sh | ./bootstrap.sh

cat <<EOF
# Auto-generated secrets from environment variables
# Generated at: $(date)

github:
  username: "${GITHUB_USERNAME:-YOUR_GITHUB_USERNAME}"
  token: "${GITHUB_TOKEN:-}"

postgresql:
  adminPassword: "${POSTGRES_ADMIN_PASSWORD:-}"

redis:
  adminPassword: "${REDIS_ADMIN_PASSWORD:-}"

letsencrypt:
  email: "${LETSENCRYPT_EMAIL:-admin@example.com}"

domain:
  base: "${DOMAIN_BASE:-example.com}"
  dev: "${DOMAIN_DEV:-dev.example.com}"
  prod: "${DOMAIN_PROD:-example.com}"

webhook:
  secret: "${WEBHOOK_SECRET:-}"

argocd:
  adminPassword: "${ARGOCD_ADMIN_PASSWORD:-}"

grafana:
  adminPassword: "${GRAFANA_ADMIN_PASSWORD:-}"

dev:
  postgresql:
    username: "${DEV_PG_USER:-core_dev_user}"
    database: "${DEV_PG_DB:-core_dev}"
  redis:
    username: "${DEV_REDIS_USER:-core_dev_user}"

prod:
  postgresql:
    username: "${PROD_PG_USER:-core_prod_user}"
    database: "${PROD_PG_DB:-core_prod}"
  redis:
    username: "${PROD_REDIS_USER:-core_prod_user}"
EOF
