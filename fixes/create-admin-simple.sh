#!/bin/bash

echo "Creating Authentik admin user..."

# Create admin user directly in database
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik << 'EOF'
-- Check if akadmin user exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM authentik_core_user WHERE username = 'akadmin') THEN
        INSERT INTO authentik_core_user (
            password,
            last_login,
            username,
            email,
            is_active,
            date_joined,
            uuid,
            name,
            path,
            type
        ) VALUES (
            'pbkdf2_sha256$600000$authentik$1A8MuFLQsld6lrhfNiTXXjngvj8HbPVzMtT1n7CHhEs=',  -- Password: Admin123!
            NULL,
            'akadmin',
            'dcversus@gmail.com',
            true,
            NOW(),
            gen_random_uuid(),
            'Admin User',
            'users',
            'internal'
        );
        RAISE NOTICE 'Created user akadmin';
    ELSE
        -- Update existing user
        UPDATE authentik_core_user
        SET
            password = 'pbkdf2_sha256$600000$authentik$1A8MuFLQsld6lrhfNiTXXjngvj8HbPVzMtT1n7CHhEs=',
            email = 'dcversus@gmail.com',
            is_active = true
        WHERE username = 'akadmin';
        RAISE NOTICE 'Updated user akadmin';
    END IF;
END$$;

-- Grant superuser permissions
INSERT INTO authentik_rbac_userrole (user_id, role_id)
SELECT u.id, r.id
FROM authentik_core_user u, authentik_rbac_role r
WHERE u.username = 'akadmin'
  AND r.name = 'Authentik Admins'
  AND NOT EXISTS (
    SELECT 1 FROM authentik_rbac_userrole ur
    WHERE ur.user_id = u.id AND ur.role_id = r.id
  );

EOF

echo ""
echo "✅ Admin user created/updated!"
echo ""
echo "Login credentials:"
echo "=================="
echo "URL: https://auth.theedgestory.org"
echo "Username: akadmin"
echo "Password: Admin123!"
echo ""
echo "Or use email:"
echo "Email: dcversus@gmail.com"
echo "Password: Admin123!"