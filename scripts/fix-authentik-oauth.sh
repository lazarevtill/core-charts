#!/bin/bash
# Fix Authentik OAuth providers using session
set -e

echo "🔧 Fixing Authentik OAuth Configuration..."
echo ""

# First, let's check what providers exist
echo "Checking existing providers in database..."
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -c "
SELECT
    p.id,
    p.name as provider_name,
    o.client_id,
    o.client_secret,
    a.slug as app_slug,
    a.name as app_name
FROM authentik_core_provider p
LEFT JOIN authentik_providers_oauth2_oauth2provider o ON p.id = o.provider_ptr_id
LEFT JOIN authentik_core_application a ON a.provider_id = p.id
WHERE p.id IN (2001, 2002, 2003, 2004) OR p.name LIKE '%ArgoCD%' OR p.name LIKE '%Grafana%' OR p.name LIKE '%Kafka%' OR p.name LIKE '%MinIO%'
ORDER BY p.id;
"

echo ""
echo "Adding scope mappings to providers..."
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik << 'EOF'
-- Ensure scope mappings are added
DO $$
DECLARE
    scope_id INTEGER;
    provider_id INTEGER;
BEGIN
    -- For each provider
    FOR provider_id IN SELECT id FROM authentik_core_provider WHERE id IN (2001, 2002, 2003, 2004)
    LOOP
        -- Add all OAuth2 scope mappings
        FOR scope_id IN
            SELECT id FROM authentik_providers_oauth2_scopemapping
            WHERE scope_name IN ('openid', 'email', 'profile', 'groups', 'offline_access')
        LOOP
            INSERT INTO authentik_core_provider_property_mappings (provider_id, propertymapping_id)
            VALUES (provider_id, scope_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END$$;

-- Verify scope mappings
SELECT
    p.name as provider,
    COUNT(pm.propertymapping_id) as scope_count
FROM authentik_core_provider p
LEFT JOIN authentik_core_provider_property_mappings pm ON p.id = pm.provider_id
WHERE p.id IN (2001, 2002, 2003, 2004)
GROUP BY p.id, p.name;
EOF

echo ""
echo "Restarting Authentik to apply changes..."
kubectl rollout restart deployment -n authentik authentik-server authentik-worker

echo ""
echo "Waiting for Authentik to restart (40 seconds)..."
sleep 40

echo ""
echo "Testing OAuth endpoints..."
for app in argocd grafana kafka-ui minio; do
    echo -n "Testing $app: "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://auth.theedgestory.org/application/o/$app/.well-known/openid-configuration)
    if [ "$STATUS" = "200" ]; then
        echo "✅ Working (HTTP $STATUS)"
        # Get the issuer URL
        ISSUER=$(curl -s https://auth.theedgestory.org/application/o/$app/.well-known/openid-configuration | python3 -c "import sys, json; print(json.load(sys.stdin).get('issuer', ''))" 2>/dev/null || echo "")
        if [ ! -z "$ISSUER" ]; then
            echo "  Issuer: $ISSUER"
        fi
    else
        echo "❌ Not working (HTTP $STATUS)"
    fi
done

echo ""
echo "If endpoints still return 404, you may need to:"
echo "1. Access https://auth.theedgestory.org/if/admin/#/core/applications"
echo "2. Verify each application has its provider assigned"
echo "3. Check that each provider has the correct OAuth2 settings"
echo ""
echo "OAuth Client Credentials:"
echo "  ArgoCD:   Client ID: argocd,   Secret: WNrNJEj5rNh4nrwM1E5lts0gmOiCYsSKKlI2wDXB"
echo "  Grafana:  Client ID: grafana,  Secret: VJHgJ40zguNCVJX53R6hai11nyxPexNcSuK3maRi"
echo "  Kafka UI: Client ID: kafka-ui, Secret: 9SAiBd0UF7q7Lw1OZGJCd7u77lNmFsXl1leKxEU"
echo "  MinIO:    Client ID: minio,    Secret: eI08IkbTKZhmxWMiW94zED6qu228SJiGBfgfTK6l"