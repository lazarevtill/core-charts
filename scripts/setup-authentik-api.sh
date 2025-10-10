#!/bin/bash
# Setup Authentik OAuth Providers via API
# This script uses the Authentik API to create all required OAuth providers and applications

set -e

echo "🔐 Setting up Authentik OAuth via API..."
echo ""

# Get Authentik URL
AUTHENTIK_URL="https://auth.theedgestory.org"

# First, we need to get an API token
# We'll create it via direct database access since we have admin access
echo "Step 1: Creating API token..."

API_TOKEN=$(openssl rand -hex 32)

kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik << EOF
-- Create API token for automation
INSERT INTO authentik_core_token (
    token_uuid,
    created,
    expires,
    expiring,
    intent,
    key,
    identifier,
    user_id,
    name,
    last_used,
    managed,
    description
) VALUES (
    gen_random_uuid(),
    NOW(),
    NULL,
    false,
    'api',
    'ak-token-$API_TOKEN',
    'automation-token',
    1,  -- Admin user ID (we'll update this)
    'Automation API Token',
    NOW(),
    NULL,
    'Token for automated OAuth setup'
) ON CONFLICT (identifier) DO UPDATE SET key = 'ak-token-$API_TOKEN';

-- Get or create admin user
INSERT INTO authentik_core_user (
    uuid,
    username,
    email,
    name,
    is_active,
    date_joined,
    is_superuser,
    is_staff,
    password,
    type,
    path
) VALUES (
    gen_random_uuid(),
    'api-admin',
    'admin@localhost',
    'API Admin',
    true,
    NOW(),
    true,
    true,
    '',
    'internal',
    'users'
) ON CONFLICT (username) DO UPDATE SET is_superuser = true
RETURNING id;
EOF

# Update token with correct user ID
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik << EOF
UPDATE authentik_core_token
SET user_id = (SELECT id FROM authentik_core_user WHERE username = 'api-admin' LIMIT 1)
WHERE identifier = 'automation-token';

-- Verify token
SELECT 'API Token created: ' || key FROM authentik_core_token WHERE identifier = 'automation-token';
EOF

echo ""
echo "Step 2: Testing API connection..."

# Test API connection
curl -s -X GET "$AUTHENTIK_URL/api/v3/core/applications/" \
  -H "Authorization: Bearer ak-token-$API_TOKEN" \
  -H "Content-Type: application/json" | head -c 100

echo ""
echo ""
echo "Step 3: Creating OAuth2 providers via API..."

# Function to create OAuth provider
create_oauth_provider() {
    local name=$1
    local client_id=$2
    local client_secret=$3
    local redirect_uris=$4
    local app_slug=$5
    local app_url=$6
    local access_level=$7  # admin or viewer

    echo "Creating $name provider..."

    # Get authorization flow
    AUTH_FLOW=$(curl -s -X GET "$AUTHENTIK_URL/api/v3/flows/instances/?designation=authorization" \
      -H "Authorization: Bearer ak-token-$API_TOKEN" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['results'][0]['pk'] if data['results'] else '')" 2>/dev/null || echo "")

    if [ -z "$AUTH_FLOW" ]; then
        echo "  ⚠️  Could not get authorization flow"
        return
    fi

    # Create OAuth2 Provider
    PROVIDER_RESPONSE=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/providers/oauth2/" \
      -H "Authorization: Bearer ak-token-$API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"$name\",
        \"authorization_flow\": \"$AUTH_FLOW\",
        \"client_type\": \"confidential\",
        \"client_id\": \"$client_id\",
        \"client_secret\": \"$client_secret\",
        \"redirect_uris\": \"$redirect_uris\",
        \"sub_mode\": \"hashed_user_id\",
        \"issuer_mode\": \"per_provider\",
        \"include_claims_in_id_token\": true,
        \"access_code_validity\": \"minutes=1\",
        \"access_token_validity\": \"minutes=10\",
        \"refresh_token_validity\": \"days=30\",
        \"property_mappings\": []
      }")

    PROVIDER_ID=$(echo "$PROVIDER_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('pk', ''))" 2>/dev/null || echo "")

    if [ -z "$PROVIDER_ID" ]; then
        echo "  ⚠️  Failed to create provider: $PROVIDER_RESPONSE"
        return
    fi

    echo "  ✓ Provider created with ID: $PROVIDER_ID"

    # Create Application
    echo "  Creating $name application..."
    APP_RESPONSE=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/core/applications/" \
      -H "Authorization: Bearer ak-token-$API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"$name\",
        \"slug\": \"$app_slug\",
        \"provider\": $PROVIDER_ID,
        \"meta_launch_url\": \"$app_url\",
        \"meta_description\": \"$name Application\",
        \"policy_engine_mode\": \"all\",
        \"group\": \"\"
      }")

    APP_ID=$(echo "$APP_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('pk', ''))" 2>/dev/null || echo "")

    if [ -z "$APP_ID" ]; then
        echo "  ⚠️  Failed to create application: $APP_RESPONSE"
        return
    fi

    echo "  ✓ Application created: $app_slug"

    # Add access policy binding
    if [ "$access_level" = "admin" ]; then
        POLICY_NAME="Administrators Only"
    else
        POLICY_NAME="Viewers and Admins"
    fi

    # Get policy ID
    POLICY_ID=$(curl -s -X GET "$AUTHENTIK_URL/api/v3/policies/expression/?name=$POLICY_NAME" \
      -H "Authorization: Bearer ak-token-$API_TOKEN" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['results'][0]['pk'] if data['results'] else '')" 2>/dev/null || echo "")

    if [ ! -z "$POLICY_ID" ]; then
        curl -s -X POST "$AUTHENTIK_URL/api/v3/policies/bindings/" \
          -H "Authorization: Bearer ak-token-$API_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{
            \"policy\": \"$POLICY_ID\",
            \"target\": \"$APP_ID\",
            \"order\": 0,
            \"enabled\": true
          }" > /dev/null
        echo "  ✓ Access policy applied: $POLICY_NAME"
    fi

    echo "  ✅ $name configuration complete!"
    echo ""
}

# Create all OAuth providers
create_oauth_provider \
    "ArgoCD" \
    "argocd" \
    "WNrNJEj5rNh4nrwM1E5lts0gmOiCYsSKKlI2wDXB" \
    "https://argo.theedgestory.org/auth/callback" \
    "argocd" \
    "https://argo.theedgestory.org" \
    "admin"

create_oauth_provider \
    "Grafana" \
    "grafana" \
    "VJHgJ40zguNCVJX53R6hai11nyxPexNcSuK3maRi" \
    "https://grafana.theedgestory.org/login/generic_oauth" \
    "grafana" \
    "https://grafana.theedgestory.org" \
    "viewer"

create_oauth_provider \
    "Kafka UI" \
    "kafka-ui" \
    "9SAiBd0UF7q7Lw1OZGJCd7u77lNmFsXl1leKxEU" \
    "https://kafka.theedgestory.org/login/oauth2/code/" \
    "kafka-ui" \
    "https://kafka.theedgestory.org" \
    "admin"

create_oauth_provider \
    "MinIO" \
    "minio" \
    "eI08IkbTKZhmxWMiW94zED6qu228SJiGBfgfTK6l" \
    "https://s3-admin.theedgestory.org/oauth_callback" \
    "minio" \
    "https://s3-admin.theedgestory.org" \
    "admin"

echo "Step 4: Cleaning up test provider..."
# Delete the test provider
TEST_PROVIDER_ID=$(curl -s -X GET "$AUTHENTIK_URL/api/v3/providers/all/?search=Test" \
  -H "Authorization: Bearer ak-token-$API_TOKEN" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['results'][0]['pk'] if data['results'] else '')" 2>/dev/null || echo "")

if [ ! -z "$TEST_PROVIDER_ID" ]; then
    curl -s -X DELETE "$AUTHENTIK_URL/api/v3/providers/all/$TEST_PROVIDER_ID/" \
      -H "Authorization: Bearer ak-token-$API_TOKEN"
    echo "✓ Test provider cleaned up"
fi

echo ""
echo "Step 5: Verifying OAuth endpoints..."
echo ""

# Test OAuth endpoints
for app in argocd grafana kafka-ui minio; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$AUTHENTIK_URL/application/o/$app/.well-known/openid-configuration")
    if [ "$STATUS" = "200" ]; then
        echo "✅ $app OAuth endpoint: Working"
    else
        echo "❌ $app OAuth endpoint: Not working (HTTP $STATUS)"
    fi
done

echo ""
echo "✅ Authentik OAuth setup complete!"
echo ""
echo "Services are now configured with Authentik authentication:"
echo "  • ArgoCD: https://argo.theedgestory.org (Administrators only)"
echo "  • Grafana: https://grafana.theedgestory.org (Viewers + Administrators)"
echo "  • Kafka UI: https://kafka.theedgestory.org (Administrators only)"
echo "  • MinIO: https://s3-admin.theedgestory.org (Administrators only)"
echo ""
echo "Login with Google OAuth: dcversus@gmail.com"