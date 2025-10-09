#!/usr/bin/env python
"""
Create Authentik admin user with password
"""
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'authentik.root.settings')
import django
django.setup()

from django.contrib.auth import get_user_model
from authentik.core.models import User as AuthUser

User = get_user_model()

# Create or update admin user
admin_user, created = User.objects.update_or_create(
    username='dcversus',
    defaults={
        'email': 'dcversus@gmail.com',
        'is_active': True,
        'is_superuser': True,
        'is_staff': True,
        'name': 'Admin User',
    }
)

# Set password
admin_user.set_password('Admin123!')
admin_user.save()

if created:
    print(f"✅ Created new admin user: {admin_user.username}")
else:
    print(f"✅ Updated existing admin user: {admin_user.username}")

print(f"   Email: {admin_user.email}")
print(f"   Password: Admin123!")
print(f"   Superuser: {admin_user.is_superuser}")
print(f"   Active: {admin_user.is_active}")
print("")
print("Login at: https://auth.theedgestory.org")
print("Username: dcversus")
print("Password: Admin123!")