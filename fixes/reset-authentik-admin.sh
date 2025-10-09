#!/bin/bash

echo "========================================="
echo "Authentik Admin Password Reset"
echo "========================================="
echo ""

# Get the running server pod
POD=$(kubectl get pods -n authentik -l app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
    echo "❌ No Authentik server pod found"
    exit 1
fi

echo "Using pod: $POD"
echo ""

# Method 1: Create recovery key
echo "Creating recovery key..."
RECOVERY_URL=$(kubectl exec -n authentik $POD -- \
    python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'authentik.root.settings')
import django
django.setup()
from django.contrib.auth import get_user_model
from authentik.core.models import Token
from datetime import timedelta
from django.utils.timezone import now

User = get_user_model()

# Get or create admin user
user, created = User.objects.get_or_create(
    username='akadmin',
    defaults={
        'email': 'dcversus@gmail.com',
        'is_active': True,
        'is_superuser': True,
        'is_staff': True,
    }
)

if created:
    print(f'Created new admin user: {user.username}')
else:
    print(f'Found existing admin user: {user.username}')
    user.email = 'dcversus@gmail.com'
    user.is_active = True
    user.is_superuser = True
    user.is_staff = True
    user.save()

# Set password
user.set_password('authentik-admin-2024')
user.save()

print(f'Password set to: authentik-admin-2024')
print(f'Email: {user.email}')
" 2>&1)

echo "$RECOVERY_URL"
echo ""

# Method 2: Alternative - Direct database update
echo "Alternative method - updating database directly..."
kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -d authentik -c "
UPDATE authentik_core_user
SET password = 'pbkdf2_sha256\$870000\$change\$UwF9mdc0vPBPoSRVwzoirZvOHqFQf4xN1c4FAYlCLlg='
WHERE username = 'akadmin' OR email = 'dcversus@gmail.com';
" 2>/dev/null

echo ""
echo "========================================="
echo "Reset Complete!"
echo "========================================="
echo ""
echo "Try logging in with:"
echo "  URL: https://auth.theedgestory.org"
echo "  Username: akadmin"
echo "  Password: authentik-admin-2024"
echo ""
echo "Or with email:"
echo "  Email: dcversus@gmail.com"
echo "  Password: authentik-admin-2024"
echo ""

# Restart pods to ensure changes take effect
echo "Restarting Authentik pods..."
kubectl rollout restart deployment authentik-server -n authentik
kubectl rollout restart deployment authentik-worker -n authentik

echo ""
echo "Wait 30 seconds for pods to restart, then try logging in."