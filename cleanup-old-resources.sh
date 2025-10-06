#!/bin/bash
set -e

echo "🧹 Cleaning Up Old/Duplicate Resources"
echo "======================================"
echo ""

# Set kubeconfig
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
fi

echo "1️⃣  Deleting old Bitnami Kafka StatefulSets (replaced by Strimzi)..."
kubectl delete statefulset infrastructure-kafka-controller -n infrastructure --ignore-not-found=true
echo "   ✅ Kafka StatefulSet deleted"

echo ""
echo "2️⃣  Deleting duplicate dev ingresses..."
kubectl delete ingress grafana-dev -n monitoring --ignore-not-found=true
echo "   ✅ grafana-dev ingress deleted"

echo ""
echo "3️⃣  Listing remaining ingresses..."
kubectl get ingress -A | grep -E "NAME|theedgestory.org"

echo ""
echo "4️⃣  Checking failed TLS certificates..."
kubectl get certificates -A | grep False || echo "   ✅ All certificates are ready"

echo ""
echo "5️⃣  Deleting old ACME HTTP solver ingresses (temporary)..."
kubectl delete ingress -n infrastructure cm-acme-http-solver-dp9bx --ignore-not-found=true
kubectl delete ingress -n minio cm-acme-http-solver-4gwzw --ignore-not-found=true
kubectl delete ingress -n minio cm-acme-http-solver-gd6sd --ignore-not-found=true
kubectl delete ingress -n minio cm-acme-http-solver-npdjn --ignore-not-found=true
echo "   ✅ Temporary ACME solvers deleted"

echo ""
echo "6️⃣  Triggering ArgoCD sync for infrastructure..."
kubectl patch application infrastructure -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'
echo "   ✅ ArgoCD sync triggered"

echo ""
echo "7️⃣  Waiting 30 seconds for sync to complete..."
sleep 30

echo ""
echo "8️⃣  Checking infrastructure pods..."
kubectl get pods -n infrastructure

echo ""
echo "======================================"
echo "✅ CLEANUP COMPLETE!"
echo ""
echo "Next steps:"
echo "  1. Wait 2-3 minutes for TLS certificates to be issued"
echo "  2. Check certificates: kubectl get certificates -A"
echo "  3. Verify ingresses: kubectl get ingress -A"
