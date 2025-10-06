#!/bin/bash
set -e

# CRITICAL: Set kubeconfig path
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "⚠️  Temporarily Disable OAuth2 on ArgoCD (Emergency Access)"
echo "============================================================"
echo ""

echo "This will remove OAuth2 authentication from ArgoCD temporarily"
echo "so you can access it while we fix the certificate issue."
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted"
  exit 1
fi

echo ""
echo "1️⃣ Removing auth annotations from ArgoCD ingress..."
kubectl annotate ingress argocd-server -n argocd \
  nginx.ingress.kubernetes.io/auth-url- \
  nginx.ingress.kubernetes.io/auth-signin- \
  --overwrite

echo "   ✅ Auth annotations removed"

echo ""
echo "2️⃣ Waiting 10 seconds for changes to propagate..."
sleep 10

echo ""
echo "3️⃣ Testing ArgoCD access..."
curl -I https://argo.theedgestory.org/ 2>&1 | grep -E "(HTTP|Location)" | head -5

echo ""
echo "✅ DONE!"
echo ""
echo "🌐 You can now access: https://argo.theedgestory.org"
echo "   (No authentication required - TEMPORARY)"
echo ""
echo "⚠️  IMPORTANT: Re-enable OAuth2 auth after fixing certificate:"
echo "   bash setup-oauth2.sh"
