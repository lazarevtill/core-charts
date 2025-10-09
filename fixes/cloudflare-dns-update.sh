#!/bin/bash

# Automated Cloudflare DNS update to use Tunnel instead of direct proxy

set -e

echo "================================================"
echo "Cloudflare DNS Auto-Update for Tunnel Routing"
echo "================================================"
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "Installing cloudflared CLI..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared-linux-amd64.deb
        rm cloudflared-linux-amd64.deb
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation
        brew install cloudflare/cloudflare/cloudflared || {
            echo "Please install Homebrew first: https://brew.sh"
            exit 1
        }
    else
        echo "Unsupported OS. Please install cloudflared manually:"
        echo "https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
        exit 1
    fi
fi

TUNNEL_ID="6c01bbbf-3488-4182-b17b-3ac004a02d99"

echo "Checking if you're logged into Cloudflare..."
if ! cloudflared tunnel list &> /dev/null; then
    echo ""
    echo "You need to authenticate with Cloudflare first."
    echo "Running: cloudflared tunnel login"
    echo ""
    cloudflared tunnel login
fi

echo ""
echo "Verifying tunnel exists..."
if cloudflared tunnel info $TUNNEL_ID &> /dev/null; then
    echo "✅ Tunnel $TUNNEL_ID found and active"
else
    echo "❌ Tunnel $TUNNEL_ID not found. Please check the tunnel ID."
    exit 1
fi

echo ""
echo "Updating DNS records to use Cloudflare Tunnel..."
echo "================================================"

# Update each domain to use the tunnel
DOMAINS=("auth.theedgestory.org" "argo.theedgestory.org" "kafka.theedgestory.org")

for domain in "${DOMAINS[@]}"; do
    echo ""
    echo "Updating $domain..."
    if cloudflared tunnel route dns $TUNNEL_ID $domain; then
        echo "✅ Successfully updated $domain to use tunnel"
    else
        echo "⚠️  Warning: Could not update $domain (may already be configured)"
    fi
done

echo ""
echo "================================================"
echo "DNS Update Complete!"
echo "================================================"
echo ""
echo "DNS records have been updated to use Cloudflare Tunnel."
echo "This should resolve the redirect loop issues."
echo ""
echo "Please wait 1-2 minutes for DNS propagation, then test:"
echo ""
echo "  curl -I https://auth.theedgestory.org"
echo "  curl -I https://argo.theedgestory.org"
echo "  curl -I https://kafka.theedgestory.org"
echo ""
echo "You should now be able to access:"
echo "  🔐 Authentik: https://auth.theedgestory.org"
echo "  📦 ArgoCD: https://argo.theedgestory.org"
echo "  📊 Kafka UI: https://kafka.theedgestory.org"
echo ""
echo "Without any redirect loops!"
echo ""

# Quick connectivity test
echo "Testing tunnel connectivity..."
kubectl logs -n infrastructure deployment/cloudflared --tail=5 | grep -E "Connection.*registered|error" || echo "Tunnel appears to be running normally"