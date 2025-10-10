#!/bin/bash
# Configure Authentik RBAC - Groups, Roles, and Policies
# This script sets up complete RBAC in Authentik

set -e

echo "🔐 Configuring Authentik RBAC System..."

# Configure RBAC in Authentik
kubectl exec -n authentik deployment/authentik-server -- python << 'EOF'
import os, django
os.environ['DJANGO_SETTINGS_MODULE'] = 'authentik.root.settings'
django.setup()

from django.contrib.auth.models import Group
from authentik.core.models import User, Application
from authentik.policies.expression.models import ExpressionPolicy
from authentik.policies.models import PolicyBinding
from authentik.rbac.models import Role
from authentik.flows.models import Flow
from authentik.stages.user_login.models import UserLoginStage
from authentik.sources.oauth.models import OAuthSource

print("=== Setting up RBAC Groups ===")

# Create Groups
admin_group, _ = Group.objects.get_or_create(name='administrators')
viewer_group, _ = Group.objects.get_or_create(name='viewers')
guest_group, _ = Group.objects.get_or_create(name='guests')

print(f"✓ Created groups: {admin_group.name}, {viewer_group.name}, {guest_group.name}")

# Create Policies for each group
print("\n=== Creating Access Policies ===")

# Admin policy - full access
admin_policy, _ = ExpressionPolicy.objects.update_or_create(
    name='Admin Access',
    defaults={
        'expression': '''
# Admin users have full access
return 'administrators' in [g.name for g in request.user.groups.all()]
'''
    }
)

# Viewer policy - read-only access
viewer_policy, _ = ExpressionPolicy.objects.update_or_create(
    name='Viewer Access',
    defaults={
        'expression': '''
# Viewers have read-only access
return 'viewers' in [g.name for g in request.user.groups.all()] or 'administrators' in [g.name for g in request.user.groups.all()]
'''
    }
)

# Guest policy - minimal access
guest_policy, _ = ExpressionPolicy.objects.update_or_create(
    name='Guest Access',
    defaults={
        'expression': '''
# Guests only see status page
return 'guests' in [g.name for g in request.user.groups.all()]
'''
    }
)

# Main dcversus policy
dcversus_policy, _ = ExpressionPolicy.objects.update_or_create(
    name='Only dcversus',
    defaults={
        'expression': 'return request.user.email == "dcversus@gmail.com"'
    }
)

print("✓ Created access policies")

# Configure Google OAuth with group assignment
print("\n=== Configuring Google OAuth with Auto-Assignment ===")

# Update Google OAuth source to auto-assign admin group to dcversus
google_source = OAuthSource.objects.filter(slug='google').first()
if google_source:
    # Create enrollment flow policy to assign groups
    enrollment_policy, _ = ExpressionPolicy.objects.update_or_create(
        name='Google OAuth Group Assignment',
        defaults={
            'expression': '''
# Automatically assign dcversus@gmail.com to administrators group
if request.user.email == "dcversus@gmail.com":
    from django.contrib.auth.models import Group
    admin_group = Group.objects.get(name='administrators')
    request.user.groups.add(admin_group)
    request.user.is_superuser = True
    request.user.is_staff = True
    request.user.save()
return True
'''
        }
    )

    # Bind policy to enrollment flow
    if google_source.enrollment_flow:
        PolicyBinding.objects.get_or_create(
            policy=enrollment_policy,
            target=google_source.enrollment_flow,
            order=10
        )
    print("✓ Configured Google OAuth with admin auto-assignment for dcversus@gmail.com")

# Assign dcversus to admin group if user exists
try:
    dcversus_user = User.objects.get(email='dcversus@gmail.com')
    dcversus_user.groups.add(admin_group)
    dcversus_user.is_superuser = True
    dcversus_user.is_staff = True
    dcversus_user.save()
    print(f"✓ Added existing user dcversus@gmail.com to administrators group")
except User.DoesNotExist:
    print("ℹ User dcversus@gmail.com will be assigned to administrators on first login")

print("\n=== RBAC Configuration Complete ===")
print("Groups created:")
print("  • administrators - Full read/write access to all services")
print("  • viewers - Read-only access to all services")
print("  • guests - Access only to status page")
print("\nPolicies created:")
print("  • Admin Access - For administrators group")
print("  • Viewer Access - For viewers group")
print("  • Guest Access - For guests group")
print("  • Only dcversus - Restricts login to dcversus@gmail.com")

# List all applications for reference
print("\n=== Current Applications ===")
for app in Application.objects.all():
    print(f"  • {app.name} (slug: {app.slug})")

EOF

echo ""
echo "✅ RBAC configuration complete!"
echo ""
echo "Next steps:"
echo "1. Configure OAuth2/OIDC applications for each service"
echo "2. Apply group-based policies to applications"
echo "3. Disable all local authentication in services"