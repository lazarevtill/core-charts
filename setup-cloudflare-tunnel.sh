#!/bin/bash
set -e

echo "🚇 Setup Cloudflare Tunnel for Kubernetes"
echo "=========================================="
echo ""
echo "This creates a secure tunnel to Cloudflare without exposing your server IP"
echo ""

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
  echo "📥 Installing cloudflared CLI..."
  curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  sudo dpkg -i cloudflared.deb
  rm cloudflared.deb
  echo "   ✅ cloudflared installed"
  echo ""
fi

echo "🔐 Step 1: Authenticate with Cloudflare"
echo "========================================"
echo "This will open a browser window to login to Cloudflare"
echo "Press Enter to continue..."
read

cloudflared tunnel login

echo ""
echo "✅ Authenticated with Cloudflare"
echo ""

echo "📝 Step 2: Create Cloudflare Tunnel"
echo "===================================="
echo "Enter tunnel name (default: k8s-tunnel): "
read TUNNEL_NAME
TUNNEL_NAME=${TUNNEL_NAME:-k8s-tunnel}

# Check if tunnel already exists
if cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
  echo "   ℹ️  Tunnel '$TUNNEL_NAME' already exists"
  TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
  echo "   Tunnel ID: $TUNNEL_ID"
else
  echo "   Creating tunnel '$TUNNEL_NAME'..."
  cloudflared tunnel create "$TUNNEL_NAME"
  TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
  echo "   ✅ Tunnel created"
  echo "   Tunnel ID: $TUNNEL_ID"
fi

echo ""

echo "3️⃣  Creating Kubernetes namespace..."
kubectl create namespace cloudflare-tunnel --dry-run=client -o yaml | kubectl apply -f -
echo "   ✅ Namespace created"
echo ""

echo "4️⃣  Creating Kubernetes secret with tunnel credentials..."
CREDS_FILE="$HOME/.cloudflared/${TUNNEL_ID}.json"

if [ ! -f "$CREDS_FILE" ]; then
  echo "   ❌ Error: Credentials file not found: $CREDS_FILE"
  exit 1
fi

kubectl create secret generic cloudflared-credentials \
  --from-file=credentials.json="$CREDS_FILE" \
  -n cloudflare-tunnel \
  --dry-run=client -o yaml | kubectl apply -f -

echo "   ✅ Credentials secret created"
echo ""

echo "5️⃣  Updating ConfigMap with tunnel ID..."
sed "s/TUNNEL_ID/$TUNNEL_ID/g" cloudflare-tunnel/deployment.yaml > /tmp/cloudflared-deployment.yaml
echo "   ✅ ConfigMap updated with tunnel ID: $TUNNEL_ID"
echo ""

echo "6️⃣  Deploying cloudflared to Kubernetes..."
kubectl apply -f /tmp/cloudflared-deployment.yaml
echo "   ✅ Cloudflared deployed"
echo ""

echo "7️⃣  Waiting for cloudflared pods to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/cloudflared -n cloudflare-tunnel
echo "   ✅ Cloudflared pods running"
echo ""

echo "8️⃣  Creating DNS records in Cloudflare..."
echo ""
echo "Run these commands to route domains through the tunnel:"
echo ""

DOMAINS=(
  "argo.theedgestory.org"
  "kafka.theedgestory.org"
  "grafana.theedgestory.org"
  "prometheus.theedgestory.org"
  "status.theedgestory.org"
  "s3-admin.theedgestory.org"
  "core-pipeline.dev.theedgestory.org"
  "core-pipeline.theedgestory.org"
  "auth.theedgestory.org"
  "theedgestory.org"
)

for domain in "${DOMAINS[@]}"; do
  echo "cloudflared tunnel route dns $TUNNEL_NAME $domain"
done

echo ""
echo "Or run this to route all domains at once:"
echo ""
cat > /tmp/route-all-domains.sh << 'SCRIPT'
#!/bin/bash
TUNNEL_NAME="$1"
DOMAINS=(
  "argo.theedgestory.org"
  "kafka.theedgestory.org"
  "grafana.theedgestory.org"
  "prometheus.theedgestory.org"
  "status.theedgestory.org"
  "s3-admin.theedgestory.org"
  "core-pipeline.dev.theedgestory.org"
  "core-pipeline.theedgestory.org"
  "auth.theedgestory.org"
  "theedgestory.org"
)

for domain in "${DOMAINS[@]}"; do
  echo "Routing $domain through tunnel..."
  cloudflared tunnel route dns "$TUNNEL_NAME" "$domain"
done
SCRIPT

chmod +x /tmp/route-all-domains.sh
echo "bash /tmp/route-all-domains.sh $TUNNEL_NAME"
echo ""

echo "9️⃣  Checking cloudflared status..."
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=20
echo ""

echo "=========================================="
echo "✅ CLOUDFLARE TUNNEL SETUP COMPLETE!"
echo ""
echo "Next steps:"
echo "  1. Route all domains through tunnel:"
echo "     bash /tmp/route-all-domains.sh $TUNNEL_NAME"
echo ""
echo "  2. Verify tunnel status:"
echo "     kubectl get pods -n cloudflare-tunnel"
echo "     kubectl logs -n cloudflare-tunnel -l app=cloudflared"
echo ""
echo "  3. Check Cloudflare dashboard:"
echo "     https://one.dash.cloudflare.com/"
echo ""
echo "  4. Test your services:"
echo "     https://argo.theedgestory.org"
echo "     https://kafka.theedgestory.org"
echo ""
echo "Benefits:"
echo "  ✅ Server IP hidden from public"
echo "  ✅ DDoS protection via Cloudflare"
echo "  ✅ No inbound ports needed (443/80 can be firewalled)"
echo "  ✅ Traffic encrypted through tunnel"
echo "  ✅ Automatic failover with 2 replicas"
echo ""
echo "Troubleshooting:"
echo "  - Tunnel logs: kubectl logs -n cloudflare-tunnel -l app=cloudflared -f"
echo "  - Tunnel info: cloudflared tunnel info $TUNNEL_NAME"
echo "  - List tunnels: cloudflared tunnel list"
echo ""
