#!/bin/bash
# Fix ArgoCD NetworkPolicies to allow GitHub access

echo "=========================================="
echo "Fixing ArgoCD Network Policies"
echo "=========================================="
echo ""

echo "=== Step 1: Check current repo-server NetworkPolicy ==="
kubectl get networkpolicy argocd-repo-server-network-policy -n argocd -o yaml
echo ""

echo "=== Step 2: Create egress rule for GitHub ==="
cat > /tmp/argocd-repo-server-netpol-fix.yaml << 'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-repo-server-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: argocd-server
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: argocd-application-controller
      ports:
        - protocol: TCP
          port: 8081
  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    # Allow all HTTPS (for GitHub and other Git repos)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
    # Allow all HTTP (for insecure repos if needed)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 80
    # Allow Git protocol
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 9418
    # Allow SSH Git
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 22
    # Allow internal cluster communication
    - to:
        - podSelector: {}
YAML

echo "Applying fixed NetworkPolicy..."
kubectl apply -f /tmp/argocd-repo-server-netpol-fix.yaml
echo ""

echo "=== Step 3: Also allow egress for application-controller ==="
cat > /tmp/argocd-app-controller-netpol-fix.yaml << 'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-application-controller-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - {}
  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    # Allow all HTTPS
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
    # Allow Kubernetes API
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 6443
    # Allow internal cluster communication
    - to:
        - podSelector: {}
YAML

kubectl apply -f /tmp/argocd-app-controller-netpol-fix.yaml
echo ""

echo "=== Step 4: Restart ArgoCD pods to pick up changes ==="
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart deployment argocd-application-controller -n argocd
echo ""

echo "Waiting for pods to be ready..."
kubectl rollout status deployment argocd-repo-server -n argocd
kubectl rollout status deployment argocd-application-controller -n argocd
echo ""

echo "✅ NetworkPolicies fixed!"
echo ""
echo "Now test GitHub connectivity:"
echo "  kubectl run test-github --rm -i --restart=Never --image=curlimages/curl:latest -- curl -I https://github.com"
