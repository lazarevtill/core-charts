#!/bin/bash
set -e

echo "🚨 EMERGENCY FIX: ArgoCD Ingress"
echo "================================"
echo ""

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "1️⃣  Checking ArgoCD server status..."
kubectl get pods -n argocd | grep argocd-server
echo ""

echo "2️⃣  Checking current ArgoCD ingress..."
if kubectl get ingress argocd-server -n argocd &>/dev/null; then
  echo "   ℹ️  ArgoCD ingress exists, showing details:"
  kubectl get ingress argocd-server -n argocd -o yaml
else
  echo "   ⚠️  ArgoCD ingress does NOT exist!"
fi
echo ""

echo "3️⃣  Applying ArgoCD ingress..."
kubectl apply -f argocd-config/argocd-ingress.yaml
echo "   ✅ ArgoCD ingress applied"
echo ""

echo "4️⃣  Waiting for ingress to be ready..."
sleep 5
kubectl get ingress argocd-server -n argocd
echo ""

echo "5️⃣  Checking TLS certificate..."
if kubectl get certificate argocd-server-tls -n argocd &>/dev/null; then
  kubectl get certificate argocd-server-tls -n argocd
else
  echo "   ⚠️  Certificate not found yet (will be created automatically)"
fi
echo ""

echo "6️⃣  Testing ArgoCD service internally..."
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -I http://argocd-server.argocd.svc.cluster.local || true
echo ""

echo "7️⃣  Checking OAuth2 Proxy status..."
kubectl get pods -n oauth2-proxy
echo ""

echo "================================"
echo "✅ ArgoCD ingress applied!"
echo ""
echo "Next steps:"
echo "  1. Wait 2-3 minutes for TLS certificate to be issued"
echo "  2. Check certificate: kubectl get certificate argocd-server-tls -n argocd"
echo "  3. Visit: https://argo.theedgestory.org"
echo ""
echo "If still getting 404:"
echo "  - Check nginx-ingress logs: kubectl logs -n kube-system -l app.kubernetes.io/name=ingress-nginx"
echo "  - Check DNS: dig +short argo.theedgestory.org (should be 46.62.223.198)"
echo "  - Check ingress class: kubectl get ingressclass"
echo ""
