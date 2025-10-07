#!/bin/bash
# Add a new authorized user to all applications

if [ -z "$1" ]; then
  echo "Usage: $0 <email@example.com>"
  exit 1
fi

EMAIL="$1"
ESCAPED_EMAIL=$(echo "$EMAIL" | sed 's/@/\\@/g' | sed 's/\./\\./g')

echo "Adding authorized user: $EMAIL"
echo ""

# Update the authorized-users.yaml file
echo "1. Updating k8s/shared-config/authorized-users.yaml..."
# Note: This is a manual step, user should edit the file

echo ""
echo "2. Apply the ConfigMap:"
echo "   kubectl apply -f k8s/shared-config/authorized-users.yaml"
echo ""
echo "3. Update ArgoCD:"
echo "   kubectl patch configmap argocd-cm -n argocd --type json -p '[{\"op\": \"add\", \"path\": \"/data/dex.config\", \"value\": \"connectors:\\n- type: google\\n  id: google\\n  name: Google\\n  config:\\n    clientID: \$dex.google.clientID\\n    clientSecret: \$dex.google.clientSecret\\n    redirectURI: https://argo.theedgestory.org/api/dex/callback\\n    allowedEmailAddresses:\\n    - dcversus@gmail.com\\n    - $EMAIL\\n\"}]'"
echo ""
echo "4. Update ArgoCD RBAC (if admin access needed):"
echo "   kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '{\"data\":{\"policy.csv\":\"g, dcversus@gmail.com, role:admin\\ng, $EMAIL, role:admin\\n\"}}'"
echo ""
echo "5. Restart services:"
echo "   kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-dex-server"
echo "   kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-server"
echo ""
echo "Note: Grafana, MinIO, and Kafka UI configurations will also need updating."
