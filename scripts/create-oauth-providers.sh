#!/bin/bash
# Create OAuth2 Providers in Authentik Database
set -e

echo "🔐 Creating OAuth2 Providers in Authentik..."

# First, get the authorization flow UUID
FLOW_UUID=$(kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -t -c "SELECT flow_uuid FROM authentik_flows_flow WHERE slug='default-provider-authorization-explicit-consent' LIMIT 1;" | xargs)

if [ -z "$FLOW_UUID" ]; then
    echo "❌ Authorization flow not found!"
    exit 1
fi

echo "Using flow UUID: $FLOW_UUID"

# Create OAuth2 providers with proper structure
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik << EOF

-- Start transaction
BEGIN;

-- Create ArgoCD provider
INSERT INTO authentik_core_provider (
    id,
    created,
    last_updated,
    name,
    authorization_flow_id,
    property_mappings,
    authentik_backchannel_providers_backchannel_applications_cache
) VALUES (
    2001,
    NOW(),
    NOW(),
    'ArgoCD',
    '$FLOW_UUID',
    '{}',
    '{}'
) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    authorization_flow_id = EXCLUDED.authorization_flow_id;

INSERT INTO authentik_providers_oauth2_oauth2provider (
    provider_ptr_id,
    client_type,
    client_id,
    client_secret,
    redirect_uris,
    include_claims_in_id_token,
    access_code_validity,
    access_token_validity,
    refresh_token_validity,
    sub_mode,
    issuer_mode
) VALUES (
    2001,
    'confidential',
    'argocd',
    'WNrNJEj5rNh4nrwM1E5lts0gmOiCYsSKKlI2wDXB',
    'https://argo.theedgestory.org/auth/callback',
    true,
    'minutes=1',
    'minutes=10',
    'days=30',
    'hashed_user_id',
    'per_provider'
) ON CONFLICT (provider_ptr_id) DO UPDATE SET
    client_secret = EXCLUDED.client_secret,
    redirect_uris = EXCLUDED.redirect_uris;

-- Create ArgoCD application
INSERT INTO authentik_core_application (
    slug,
    created,
    last_updated,
    name,
    meta_launch_url,
    meta_icon,
    meta_description,
    meta_publisher,
    policy_engine_mode,
    provider_id,
    "group"
) VALUES (
    'argocd',
    NOW(),
    NOW(),
    'ArgoCD',
    'https://argo.theedgestory.org',
    '',
    'GitOps Continuous Deployment',
    'authentik',
    'any',
    2001,
    ''
) ON CONFLICT (slug) DO UPDATE SET
    provider_id = EXCLUDED.provider_id,
    name = EXCLUDED.name;

-- Create Grafana provider
INSERT INTO authentik_core_provider (
    id,
    created,
    last_updated,
    name,
    authorization_flow_id,
    property_mappings,
    authentik_backchannel_providers_backchannel_applications_cache
) VALUES (
    2002,
    NOW(),
    NOW(),
    'Grafana',
    '$FLOW_UUID',
    '{}',
    '{}'
) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    authorization_flow_id = EXCLUDED.authorization_flow_id;

INSERT INTO authentik_providers_oauth2_oauth2provider (
    provider_ptr_id,
    client_type,
    client_id,
    client_secret,
    redirect_uris,
    include_claims_in_id_token,
    access_code_validity,
    access_token_validity,
    refresh_token_validity,
    sub_mode,
    issuer_mode
) VALUES (
    2002,
    'confidential',
    'grafana',
    'VJHgJ40zguNCVJX53R6hai11nyxPexNcSuK3maRi',
    'https://grafana.theedgestory.org/login/generic_oauth',
    true,
    'minutes=1',
    'minutes=10',
    'days=30',
    'hashed_user_id',
    'per_provider'
) ON CONFLICT (provider_ptr_id) DO UPDATE SET
    client_secret = EXCLUDED.client_secret,
    redirect_uris = EXCLUDED.redirect_uris;

-- Create Grafana application
INSERT INTO authentik_core_application (
    slug,
    created,
    last_updated,
    name,
    meta_launch_url,
    meta_icon,
    meta_description,
    meta_publisher,
    policy_engine_mode,
    provider_id,
    "group"
) VALUES (
    'grafana',
    NOW(),
    NOW(),
    'Grafana',
    'https://grafana.theedgestory.org',
    '',
    'Monitoring & Analytics',
    'authentik',
    'any',
    2002,
    ''
) ON CONFLICT (slug) DO UPDATE SET
    provider_id = EXCLUDED.provider_id,
    name = EXCLUDED.name;

-- Create Kafka UI provider
INSERT INTO authentik_core_provider (
    id,
    created,
    last_updated,
    name,
    authorization_flow_id,
    property_mappings,
    authentik_backchannel_providers_backchannel_applications_cache
) VALUES (
    2003,
    NOW(),
    NOW(),
    'Kafka UI',
    '$FLOW_UUID',
    '{}',
    '{}'
) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    authorization_flow_id = EXCLUDED.authorization_flow_id;

INSERT INTO authentik_providers_oauth2_oauth2provider (
    provider_ptr_id,
    client_type,
    client_id,
    client_secret,
    redirect_uris,
    include_claims_in_id_token,
    access_code_validity,
    access_token_validity,
    refresh_token_validity,
    sub_mode,
    issuer_mode
) VALUES (
    2003,
    'confidential',
    'kafka-ui',
    '9SAiBd0UF7q7Lw1OZGJCd7u77lNmFsXl1leKxEU',
    'https://kafka.theedgestory.org/login/oauth2/code/',
    true,
    'minutes=1',
    'minutes=10',
    'days=30',
    'hashed_user_id',
    'per_provider'
) ON CONFLICT (provider_ptr_id) DO UPDATE SET
    client_secret = EXCLUDED.client_secret,
    redirect_uris = EXCLUDED.redirect_uris;

-- Create Kafka UI application
INSERT INTO authentik_core_application (
    slug,
    created,
    last_updated,
    name,
    meta_launch_url,
    meta_icon,
    meta_description,
    meta_publisher,
    policy_engine_mode,
    provider_id,
    "group"
) VALUES (
    'kafka-ui',
    NOW(),
    NOW(),
    'Kafka UI',
    'https://kafka.theedgestory.org',
    '',
    'Kafka Management Console',
    'authentik',
    'any',
    2003,
    ''
) ON CONFLICT (slug) DO UPDATE SET
    provider_id = EXCLUDED.provider_id,
    name = EXCLUDED.name;

-- Create MinIO provider
INSERT INTO authentik_core_provider (
    id,
    created,
    last_updated,
    name,
    authorization_flow_id,
    property_mappings,
    authentik_backchannel_providers_backchannel_applications_cache
) VALUES (
    2004,
    NOW(),
    NOW(),
    'MinIO',
    '$FLOW_UUID',
    '{}',
    '{}'
) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    authorization_flow_id = EXCLUDED.authorization_flow_id;

INSERT INTO authentik_providers_oauth2_oauth2provider (
    provider_ptr_id,
    client_type,
    client_id,
    client_secret,
    redirect_uris,
    include_claims_in_id_token,
    access_code_validity,
    access_token_validity,
    refresh_token_validity,
    sub_mode,
    issuer_mode
) VALUES (
    2004,
    'confidential',
    'minio',
    'eI08IkbTKZhmxWMiW94zED6qu228SJiGBfgfTK6l',
    'https://s3-admin.theedgestory.org/oauth_callback',
    true,
    'minutes=1',
    'minutes=10',
    'days=30',
    'hashed_user_id',
    'per_provider'
) ON CONFLICT (provider_ptr_id) DO UPDATE SET
    client_secret = EXCLUDED.client_secret,
    redirect_uris = EXCLUDED.redirect_uris;

-- Create MinIO application
INSERT INTO authentik_core_application (
    slug,
    created,
    last_updated,
    name,
    meta_launch_url,
    meta_icon,
    meta_description,
    meta_publisher,
    policy_engine_mode,
    provider_id,
    "group"
) VALUES (
    'minio',
    NOW(),
    NOW(),
    'MinIO Console',
    'https://s3-admin.theedgestory.org',
    '',
    'Object Storage Management',
    'authentik',
    'any',
    2004,
    ''
) ON CONFLICT (slug) DO UPDATE SET
    provider_id = EXCLUDED.provider_id,
    name = EXCLUDED.name;

-- Add scope mappings (required for OAuth2)
DO \$\$
DECLARE
    scope_mapping_id INTEGER;
BEGIN
    -- Get the default OAuth2 scope mapping IDs
    FOR scope_mapping_id IN
        SELECT id FROM authentik_providers_oauth2_scopemapping
        WHERE scope_name IN ('openid', 'email', 'profile', 'groups')
    LOOP
        -- Add scope mappings to each provider
        INSERT INTO authentik_core_provider_property_mappings (provider_id, propertymapping_id)
        VALUES
            (2001, scope_mapping_id),
            (2002, scope_mapping_id),
            (2003, scope_mapping_id),
            (2004, scope_mapping_id)
        ON CONFLICT DO NOTHING;
    END LOOP;
END\$\$;

COMMIT;

-- Verify creation
SELECT 'OAuth Providers Created:' as status;
SELECT p.id, p.name, o.client_id, a.slug as app_slug
FROM authentik_core_provider p
JOIN authentik_providers_oauth2_oauth2provider o ON p.id = o.provider_ptr_id
LEFT JOIN authentik_core_application a ON a.provider_id = p.id
WHERE p.id IN (2001, 2002, 2003, 2004)
ORDER BY p.id;

EOF

echo ""
echo "✅ OAuth2 Providers created successfully!"
echo ""
echo "Testing ArgoCD OAuth endpoint..."
curl -s -o /dev/null -w "ArgoCD OAuth endpoint: %{http_code}\n" https://auth.theedgestory.org/application/o/argocd/.well-known/openid-configuration

echo ""
echo "You can now access services with Authentik authentication:"
echo "  • ArgoCD: https://argo.theedgestory.org"
echo "  • Grafana: https://grafana.theedgestory.org"
echo "  • Kafka UI: https://kafka.theedgestory.org"
echo "  • MinIO: https://s3-admin.theedgestory.org"