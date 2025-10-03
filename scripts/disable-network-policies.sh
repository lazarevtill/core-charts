#!/bin/bash
# Disable K3s/kube-router NetworkPolicy enforcement to allow external internet access

echo "=========================================="
echo "Disabling NetworkPolicy Enforcement"
echo "=========================================="
echo ""

echo "=== Option 1: Restart K3s without network-policy ==="
echo "Edit K3s configuration to disable NetworkPolicy..."
echo ""

# Check current K3s config
echo "Current K3s server args:"
ps aux | grep k3s | grep -v grep
echo ""

echo "To permanently disable NetworkPolicy, edit K3s service:"
echo "  sudo systemctl edit --full k3s"
echo ""
echo "Find the line with 'ExecStart' and remove '--kube-proxy-arg=network-policy=...'"
echo "Or add: --disable-network-policy"
echo ""

echo "=== Option 2: Delete all NetworkPolicies (temporary fix) ==="
echo "This will remove NetworkPolicy restrictions:"
echo ""

read -p "Delete all NetworkPolicies? (y/N): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  echo "Deleting NetworkPolicies..."
  kubectl delete networkpolicies --all --all-namespaces
  
  echo ""
  echo "✅ All NetworkPolicies deleted!"
  echo ""
  echo "Testing GitHub connectivity..."
  kubectl run test-no-netpol --rm -i --restart=Never --image=curlimages/curl:latest -- \
    curl -I -m 10 https://github.com | head -5
else
  echo "Skipped NetworkPolicy deletion"
fi

echo ""
echo "=========================================="
echo "Alternative: Manual K3s Restart"
echo "=========================================="
echo ""
echo "If NetworkPolicy deletion didn't work, restart K3s with NetworkPolicy disabled:"
echo ""
echo "1. Edit K3s service:"
echo "   sudo nano /etc/systemd/system/k3s.service"
echo ""
echo "2. Add to ExecStart line:"
echo "   --disable-network-policy"
echo ""
echo "3. Reload and restart:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl restart k3s"
echo ""
echo "4. Test connectivity again"
