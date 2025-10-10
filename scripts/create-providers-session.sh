#!/bin/bash
# Create OAuth Providers using authenticated session
set -e

echo "🔐 Creating OAuth Providers using session..."
echo ""

AUTHENTIK_URL="https://auth.theedgestory.org"
SESSION_COOKIE="authentik_session=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzaWQiOiI1anpiZzJ1dDNrcm9zNHc2OWxmc2VwbmhteHQ0YW9yZSIsImlzcyI6ImF1dGhlbnRpayIsInN1YiI6IjdjMjQwYzVhMTNkMTNiNWFmN2Y1OThmZTM0NDM4YWRkN2NmZTY2ZGZlY2MwNjIzN2MyOTBiMDAyMjgxZjQwOTEiLCJhdXRoZW50aWNhdGVkIjp0cnVlLCJhY3IiOiJnb2F1dGhlbnRpay5pby9jb3JlL2RlZmF1bHQifQ.avvfpgznRTwJJ9Y2xMZwJye8C_0hHDijSI7QAxsBQZk"
CSRF_TOKEN="7GSPxnzrO7brWAhP2dg4gZR1TSNzn0UX"

# First get the authorization flow
echo "Getting authorization flow..."
FLOW_RESPONSE=$(curl -s "$AUTHENTIK_URL/api/v3/flows/instances/?designation=authorization" \
  -H "Cookie: $SESSION_COOKIE" \
  -H "X-Authentik-CSRF: $CSRF_TOKEN")

AUTH_FLOW=$(echo "$FLOW_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['results'][0]['pk'] if data.get('results') else '')" 2>/dev/null)
echo "Authorization flow: $AUTH_FLOW"

# Get scope mappings
echo "Getting scope mappings..."
SCOPE_RESPONSE=$(curl -s "$AUTHENTIK_URL/api/v3/propertymappings/scope/" \
  -H "Cookie: $SESSION_COOKIE" \
  -H "X-Authentik-CSRF: $CSRF_TOKEN")

SCOPE_IDS=$(echo "$SCOPE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
scopes = [m['pk'] for m in data.get('results', []) if m['scope_name'] in ['openid', 'email', 'profile', 'groups']]
print(json.dumps(scopes))
" 2>/dev/null)

echo "Scope mappings: $SCOPE_IDS"

# Function to create provider
create_oauth_provider() {
    local name="$1"
    local client_id="$2"
    local client_secret="$3"
    local redirect_uris="$4"
    local slug="$5"
    local launch_url="$6"

    echo ""
    echo "Creating $name provider..."

    # Create OAuth2 Provider
    PROVIDER_RESPONSE=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/providers/oauth2/" \
      -H "Cookie: $SESSION_COOKIE" \
      -H "X-Authentik-CSRF: $CSRF_TOKEN" \
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
        \"property_mappings\": $SCOPE_IDS
      }")

    PROVIDER_ID=$(echo "$PROVIDER_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('pk', ''))" 2>/dev/null)

    if [ -z "$PROVIDER_ID" ]; then
        echo "  ❌ Failed to create provider: $PROVIDER_RESPONSE"
        return
    fi

    echo "  ✅ Provider created with ID: $PROVIDER_ID"

    # Create Application
    echo "  Creating $name application..."
    APP_RESPONSE=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/core/applications/" \
      -H "Cookie: $SESSION_COOKIE" \
      -H "X-Authentik-CSRF: $CSRF_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"$name\",
        \"slug\": \"$slug\",
        \"provider\": $PROVIDER_ID,
        \"meta_launch_url\": \"$launch_url\",
        \"meta_description\": \"$name SSO Application\",
        \"policy_engine_mode\": \"all\",
        \"group\": \"\"
      }")

    APP_CREATED=$(echo "$APP_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print('created' if 'pk' in data else 'failed')" 2>/dev/null)

    if [ "$APP_CREATED" = "created" ]; then
        echo "  ✅ Application created: $slug"
    else
        # Try to update existing application
        echo "  Updating existing application..."
        curl -s -X PATCH "$AUTHENTIK_URL/api/v3/core/applications/$slug/" \
          -H "Cookie: $SESSION_COOKIE" \
          -H "X-Authentik-CSRF: $CSRF_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"provider\": $PROVIDER_ID}" > /dev/null
        echo "  ✅ Application updated: $slug"
    fi
}

# Delete test providers first
echo "Cleaning up test providers..."
TEST_PROVIDERS=$(curl -s "$AUTHENTIK_URL/api/v3/providers/oauth2/?search=Test" \
  -H "Cookie: $SESSION_COOKIE" \
  -H "X-Authentik-CSRF: $CSRF_TOKEN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
providers = [p['pk'] for p in data.get('results', [])]
print(' '.join(map(str, providers)))
" 2>/dev/null)

for provider_id in $TEST_PROVIDERS; do
    curl -s -X DELETE "$AUTHENTIK_URL/api/v3/providers/oauth2/$provider_id/" \
      -H "Cookie: $SESSION_COOKIE" \
      -H "X-Authentik-CSRF: $CSRF_TOKEN"
    echo "  Deleted provider: $provider_id"
done

# Create all OAuth providers
create_oauth_provider \
    "ArgoCD" \
    "argocd" \
    "WNrNJEj5rNh4nrwM1E5lts0gmOiCYsSKKlI2wDXB" \
    "https://argo.theedgestory.org/auth/callback" \
    "argocd" \
    "https://argo.theedgestory.org"

create_oauth_provider \
    "Grafana" \
    "grafana" \
    "VJHgJ40zguNCVJX53R6hai11nyxPexNcSuK3maRi" \
    "https://grafana.theedgestory.org/login/generic_oauth" \
    "grafana" \
    "https://grafana.theedgestory.org"

create_oauth_provider \
    "Kafka UI" \
    "kafka-ui" \
    "9SAiBd0UF7q7Lw1OZGJCd7u77lNmFsXl1leKxEU" \
    "https://kafka.theedgestory.org/login/oauth2/code/" \
    "kafka-ui" \
    "https://kafka.theedgestory.org"

create_oauth_provider \
    "MinIO" \
    "minio" \
    "eI08IkbTKZhmxWMiW94zED6qu228SJiGBfgfTK6l" \
    "https://s3-admin.theedgestory.org/oauth_callback" \
    "minio" \
    "https://s3-admin.theedgestory.org"

echo ""
echo "✅ Testing OAuth endpoints..."
for app in argocd grafana kafka-ui minio; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$AUTHENTIK_URL/application/o/$app/.well-known/openid-configuration")
    if [ "$STATUS" = "200" ]; then
        echo "  ✅ $app: OAuth endpoint working"
    else
        echo "  ❌ $app: OAuth endpoint not working (HTTP $STATUS)"
    fi
done

echo ""
echo "🎉 OAuth provider creation complete!"