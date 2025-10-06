#!/bin/bash
set -e

echo "🔐 Setup Cloudflare DNS-01 Challenge for cert-manager"
echo "====================================================="
echo ""
echo "This allows TLS certificates to work with Cloudflare proxy enabled (orange cloud)"
echo ""

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "📋 Step 1: Create Cloudflare API Token"
echo "======================================="
echo ""
echo "Go to: https://dash.cloudflare.com/profile/api-tokens"
echo ""
echo "Click 'Create Token' and use 'Edit zone DNS' template:"
echo "  - Permissions: Zone / DNS / Edit"
echo "  - Zone Resources: Include / Specific zone / theedgestory.org"
echo ""
echo "Copy the API token and paste it below:"
echo ""
read -sp "Cloudflare API Token: " CLOUDFLARE_API_TOKEN
echo ""
echo ""

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  echo "❌ Error: No API token provided"
  exit 1
fi

echo "2️⃣  Creating Kubernetes secret with Cloudflare API token..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
  -n cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -
echo "   ✅ Secret created: cloudflare-api-token"
echo ""

echo "3️⃣  Applying Cloudflare ClusterIssuer..."
kubectl apply -f cert-manager/cloudflare-issuer.yaml
echo "   ✅ ClusterIssuer created: letsencrypt-cloudflare"
echo ""

echo "4️⃣  Checking ClusterIssuer status..."
sleep 3
kubectl get clusterissuer letsencrypt-cloudflare -o wide
echo ""

echo "5️⃣  Updating ArgoCD ingress to use Cloudflare issuer..."
kubectl patch ingress argocd-server -n argocd --type=json -p='[
  {
    "op": "replace",
    "path": "/metadata/annotations/cert-manager.io~1cluster-issuer",
    "value": "letsencrypt-cloudflare"
  }
]'
echo "   ✅ ArgoCD ingress updated"
echo ""

echo "6️⃣  Deleting old certificate to trigger reissue..."
kubectl delete certificate argocd-server-tls -n argocd --ignore-not-found=true
echo "   ✅ Old certificate deleted (will be recreated automatically)"
echo ""

echo "7️⃣  Waiting for new certificate to be issued (DNS-01 challenge)..."
echo "   This may take 2-5 minutes..."
sleep 10

for i in {1..20}; do
  if kubectl get certificate argocd-server-tls -n argocd &>/dev/null; then
    STATUS=$(kubectl get certificate argocd-server-tls -n argocd -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$STATUS" = "True" ]; then
      echo "   ✅ Certificate issued successfully!"
      break
    else
      echo "   ⏳ Waiting for certificate... ($i/20)"
      sleep 15
    fi
  else
    echo "   ⏳ Waiting for certificate to be created... ($i/20)"
    sleep 15
  fi
done

echo ""
echo "8️⃣  Final certificate status:"
kubectl get certificate argocd-server-tls -n argocd
echo ""

echo "====================================================="
echo "✅ CLOUDFLARE DNS-01 CHALLENGE CONFIGURED!"
echo ""
echo "Next steps:"
echo "  1. All domains can now stay behind Cloudflare proxy (orange cloud)"
echo "  2. Visit: https://argo.theedgestory.org"
echo "  3. Update all other ingresses to use: letsencrypt-cloudflare issuer"
echo ""
echo "To update other ingresses:"
echo "  kubectl patch ingress <name> -n <namespace> --type=json -p='["
echo "    {"
echo "      \"op\": \"replace\","
echo "      \"path\": \"/metadata/annotations/cert-manager.io~1cluster-issuer\","
echo "      \"value\": \"letsencrypt-cloudflare\""
echo "    }"
echo "  ]'"
echo ""
echo "Troubleshooting:"
echo "  - Check ClusterIssuer: kubectl describe clusterissuer letsencrypt-cloudflare"
echo "  - Check certificate: kubectl describe certificate argocd-server-tls -n argocd"
echo "  - Check cert-manager logs: kubectl logs -n cert-manager -l app=cert-manager"
echo ""
