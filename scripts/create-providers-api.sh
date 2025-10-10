#!/bin/bash
# Create OAuth Providers via Authentik API
set -e

echo "🔐 Creating OAuth Providers via Authentik API..."
echo ""

AUTHENTIK_URL="https://auth.theedgestory.org"

# Step 1: Create a proper API token for akadmin
echo "Step 1: Creating API token for akadmin..."

kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik << 'EOF'
-- Delete old test tokens
DELETE FROM authentik_core_token WHERE identifier LIKE 'api-automation-%';

-- Create new API token for akadmin user
INSERT INTO authentik_core_token (
    token_uuid,
    key,
    identifier,
    user_id,
    name,
    expiring,
    expires,
    description,
    intent
) VALUES (
    gen_random_uuid(),
    'authentik-api-' || encode(gen_random_bytes(32), 'hex'),
    'api-automation-admin',
    4,  -- akadmin user id
    'Admin API Token',
    false,
    NULL,
    'API token for provider creation',
    'api'
) RETURNING key;
EOF

# Get the token we just created
API_TOKEN=$(kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c "SELECT key FROM authentik_core_token WHERE identifier='api-automation-admin';" | xargs)

echo "API Token created: ${API_TOKEN:0:20}..."
echo ""

# Step 2: Test the token
echo "Step 2: Testing API connection..."
USER_RESPONSE=$(curl -s "$AUTHENTIK_URL/api/v3/core/users/me/" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json")

USERNAME=$(echo "$USER_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('username', 'Unknown'))" 2>/dev/null || echo "Unknown")
echo "Authenticated as: $USERNAME"

if [ "$USERNAME" = "Unknown" ] || [ "$USERNAME" = "null" ]; then
    echo "❌ Authentication failed. Response: $USER_RESPONSE"
    exit 1
fi

echo ""
echo "Step 3: Getting authorization flow..."

# Get the authorization flow UUID
AUTH_FLOW=$(curl -s "$AUTHENTIK_URL/api/v3/flows/instances/?designation=authorization" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" | python3 -c "import sys, json; data=json.load(sys.stdin); flows=[f for f in data.get('results', []) if 'explicit' in f.get('slug', '')]; print(flows[0]['pk'] if flows else '')" 2>/dev/null)

if [ -z "$AUTH_FLOW" ]; then
    # Try another method
    AUTH_FLOW=$(curl -s "$AUTHENTIK_URL/api/v3/flows/instances/" \
      -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys, json; data=json.load(sys.stdin); flows=[f for f in data.get('results', []) if f.get('designation')=='authorization']; print(flows[0]['pk'] if flows else '')" 2>/dev/null)
fi

echo "Authorization flow: $AUTH_FLOW"

if [ -z "$AUTH_FLOW" ]; then
    echo "❌ Could not find authorization flow"
    exit 1
fi

echo ""
echo "Step 4: Getting scope mappings..."

# Get OAuth2 scope mappings
SCOPE_MAPPINGS=$(curl -s "$AUTHENTIK_URL/api/v3/propertymappings/scope/" \
  -H "Authorization: Bearer $API_TOKEN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
mappings = [str(m['pk']) for m in data.get('results', []) if m['scope_name'] in ['openid', 'email', 'profile', 'groups']]
print(','.join(mappings))
" 2>/dev/null)

echo "Scope mappings: $SCOPE_MAPPINGS"

# Convert to JSON array
SCOPE_ARRAY=$(echo "[$SCOPE_MAPPINGS]" | sed 's/,/","/g' | sed 's/\[/["/' | sed 's/\]$/"]/')

echo ""
echo "Step 5: Creating OAuth2 Providers..."

# Function to create provider and application
create_provider() {
    local name="$1"
    local client_id="$2"
    local client_secret="$3"
    local redirect_uris="$4"
    local slug="$5"
    local launch_url="$6"

    echo ""
    echo "Creating $name..."

    # Create OAuth2 Provider
    PROVIDER_RESPONSE=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/providers/oauth2/" \
      -H "Authorization: Bearer $API_TOKEN" \
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
        \"property_mappings\": $SCOPE_ARRAY
      }")

    # Check if provider was created
    PROVIDER_ID=$(echo "$PROVIDER_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('pk', ''))" 2>/dev/null)

    if [ -z "$PROVIDER_ID" ] || [ "$PROVIDER_ID" = "" ]; then
        echo "  ❌ Failed to create provider"
        echo "  Response: $PROVIDER_RESPONSE"
        return
    fi

    echo "  ✅ Provider created with ID: $PROVIDER_ID"

    # Create Application
    APP_RESPONSE=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/core/applications/" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"$name\",
        \"slug\": \"$slug\",
        \"provider\": $PROVIDER_ID,
        \"meta_launch_url\": \"$launch_url\",
        \"meta_description\": \"$name SSO\",
        \"policy_engine_mode\": \"all\",
        \"group\": \"\"
      }")

    APP_SLUG=$(echo "$APP_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('slug', ''))" 2>/dev/null)

    if [ "$APP_SLUG" = "$slug" ]; then
        echo "  ✅ Application created: $slug"
    else
        echo "  ⚠️  Application may exist or failed"
        # Try to update existing application
        curl -s -X PATCH "$AUTHENTIK_URL/api/v3/core/applications/$slug/" \
          -H "Authorization: Bearer $API_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"provider\": $PROVIDER_ID}" > /dev/null 2>&1
    fi
}

# Delete test provider first
echo "Cleaning up test providers..."
TEST_PROVIDERS=$(curl -s "$AUTHENTIK_URL/api/v3/providers/oauth2/" \
  -H "Authorization: Bearer $API_TOKEN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
test_providers = [str(p['pk']) for p in data.get('results', []) if 'test' in p.get('name', '').lower()]
print(' '.join(test_providers))
" 2>/dev/null)

for provider_id in $TEST_PROVIDERS; do
    curl -s -X DELETE "$AUTHENTIK_URL/api/v3/providers/oauth2/$provider_id/" \
      -H "Authorization: Bearer $API_TOKEN"
    echo "  Deleted test provider: $provider_id"
done

# Create all providers
create_provider \
    "ArgoCD" \
    "argocd" \
    "WNrNJEj5rNh4nrwM1E5lts0gmOiCYsSKKlI2wDXB" \
    "https://argo.theedgestory.org/auth/callback" \
    "argocd" \
    "https://argo.theedgestory.org"

create_provider \
    "Grafana" \
    "grafana" \
    "VJHgJ40zguNCVJX53R6hai11nyxPexNcSuK3maRi" \
    "https://grafana.theedgestory.org/login/generic_oauth" \
    "grafana" \
    "https://grafana.theedgestory.org"

create_provider \
    "Kafka UI" \
    "kafka-ui" \
    "9SAiBd0UF7q7Lw1OZGJCd7u77lNmFsXl1leKxEU" \
    "https://kafka.theedgestory.org/login/oauth2/code/" \
    "kafka-ui" \
    "https://kafka.theedgestory.org"

create_provider \
    "MinIO" \
    "minio" \
    "eI08IkbTKZhmxWMiW94zED6qu228SJiGBfgfTK6l" \
    "https://s3-admin.theedgestory.org/oauth_callback" \
    "minio" \
    "https://s3-admin.theedgestory.org"

echo ""
echo "Step 6: Verifying OAuth endpoints..."
echo ""

# Test each endpoint
for app in argocd grafana kafka-ui minio; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$AUTHENTIK_URL/application/o/$app/.well-known/openid-configuration")
    if [ "$STATUS" = "200" ]; then
        echo "✅ $app: OAuth endpoint working (HTTP $STATUS)"
        # Show the issuer URL
        ISSUER=$(curl -s "$AUTHENTIK_URL/application/o/$app/.well-known/openid-configuration" | python3 -c "import sys, json; print(json.load(sys.stdin).get('issuer', ''))" 2>/dev/null)
        echo "   Issuer: $ISSUER"
    else
        echo "❌ $app: OAuth endpoint not working (HTTP $STATUS)"
    fi
done

echo ""
echo "✅ Provider creation complete!"
echo ""
echo "Services configured with Authentik OAuth:"
echo "  • ArgoCD: https://argo.theedgestory.org"
echo "  • Grafana: https://grafana.theedgestory.org"
echo "  • Kafka UI: https://kafka.theedgestory.org"
echo "  • MinIO: https://s3-admin.theedgestory.org"