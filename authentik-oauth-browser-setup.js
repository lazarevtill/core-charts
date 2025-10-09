// Authentik Google OAuth Setup - Browser Console Script
//
// Instructions:
// 1. Login to Authentik at https://auth.theedgestory.org
//    Username: akadmin
//    Password: Admin123!
//
// 2. Open Browser Developer Tools (F12) and go to Console tab
//
// 3. Replace these with your actual Google OAuth credentials:
const GOOGLE_CLIENT_ID = 'YOUR_CLIENT_ID_HERE';
const GOOGLE_CLIENT_SECRET = 'YOUR_SECRET_HERE';

// 4. Copy and paste this entire script into the console and press Enter

(async () => {
  // Get CSRF token from cookies
  const csrfToken = document.cookie.match(/authentik_csrf=([^;]+)/)?.[1];

  if (!csrfToken) {
    console.error('❌ No CSRF token found. Make sure you are logged into Authentik.');
    return;
  }

  console.log('🔍 Found CSRF token, creating Google OAuth source...');

  try {
    const response = await fetch('/api/v3/sources/oauth/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Authentik-CSRF': csrfToken,
        'X-CSRFToken': csrfToken
      },
      body: JSON.stringify({
        name: 'Google',
        slug: 'google',
        enabled: true,
        provider_type: 'google',
        consumer_key: GOOGLE_CLIENT_ID,
        consumer_secret: GOOGLE_CLIENT_SECRET,
        authentication_flow: null,
        enrollment_flow: null,
        user_matching_mode: 'email_deny',
        user_path_template: 'goauthentik.io/sources/%(slug)s',
        group_matching_mode: 'identifier',
        additional_scopes: '',
        oidc_well_known_url: '',
        oidc_jwks_url: '',
        access_token_url: '',
        authorization_url: '',
        profile_url: '',
        request_token_url: ''
      }),
      credentials: 'same-origin'
    });

    const data = await response.json();

    if (response.ok && data.slug) {
      console.log('✅ SUCCESS! Google OAuth source created!');
      console.log('');
      console.log('📋 Source Details:');
      console.log(`   Name: ${data.name}`);
      console.log(`   Slug: ${data.slug}`);
      console.log(`   Provider: ${data.provider_type}`);
      console.log(`   Status: ${data.enabled ? 'Enabled' : 'Disabled'}`);
      console.log('');
      console.log('🔗 Important: Add this redirect URI to your Google Cloud Console:');
      console.log('   https://auth.theedgestory.org/source/oauth/callback/google/');
      console.log('');
      console.log('📝 Next Steps:');
      console.log('1. Go to https://console.cloud.google.com');
      console.log('2. Navigate to APIs & Services → Credentials');
      console.log('3. Edit your OAuth 2.0 Client');
      console.log('4. Add the redirect URI above to "Authorized redirect URIs"');
      console.log('5. Save the changes');
      console.log('');
      console.log('🚀 Redirecting to sources page...');

      setTimeout(() => {
        window.location.href = '/if/admin/#/core/sources';
      }, 3000);

    } else if (data.non_field_errors && data.non_field_errors[0].includes('already exists')) {
      console.warn('⚠️  Google OAuth source already exists');
      console.log('Redirecting to sources page to view it...');
      setTimeout(() => {
        window.location.href = '/if/admin/#/core/sources';
      }, 2000);
    } else {
      console.error('❌ Failed to create OAuth source:');
      console.error(data);

      if (data.detail && data.detail.includes('CSRF')) {
        console.error('');
        console.error('CSRF token issue. Please try refreshing the page and running the script again.');
      }
    }

  } catch (error) {
    console.error('❌ Error creating OAuth source:', error);
    console.error('');
    console.error('Please check:');
    console.error('1. You are logged into Authentik');
    console.error('2. You replaced the CLIENT_ID and SECRET with your actual values');
    console.error('3. Try refreshing the page and running again');
  }
})();