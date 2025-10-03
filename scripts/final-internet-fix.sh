#!/bin/bash
# Final fix for K3s pod internet connectivity

echo "=========================================="
echo "Final K3s Internet Connectivity Fix"
echo "=========================================="
echo ""

echo "Problem: kube-router NetworkPolicy enforcement is blocking external traffic"
echo "Solution: Add explicit ACCEPT rule before kube-router processing"
echo ""

# Add ACCEPT rule BEFORE kube-router chain
echo "=== Adding bypass rule for external traffic ==="
if sudo iptables -C FORWARD -o eth0 -j ACCEPT 2>/dev/null; then
  echo "✓ Bypass rule already exists"
else
  # Insert at position 1, before KUBE-ROUTER-FORWARD
  sudo iptables -I FORWARD 1 -o eth0 -j ACCEPT
  echo "✅ Added ACCEPT rule for outbound traffic on eth0"
fi

# Also ensure return traffic is allowed
if sudo iptables -C FORWARD -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
  echo "✓ Return traffic rule already exists"
else
  sudo iptables -I FORWARD 2 -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT
  echo "✅ Added ACCEPT rule for return traffic"
fi

echo ""
echo "=== Current FORWARD rules (first 5) ==="
sudo iptables -L FORWARD -n -v | head -8

echo ""
echo "=== Testing GitHub connectivity ==="
kubectl run test-final-fix --rm -i --restart=Never --image=curlimages/curl:latest -- \
  curl -I -m 10 https://github.com 2>&1 | head -10

echo ""
echo "=== Saving rules ==="
sudo mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
echo "✅ Rules saved"

echo ""
echo "If the test succeeded, your pods can now reach GitHub!"
echo "If it still fails, the only option is to disable NetworkPolicy in K3s entirely:"
echo ""
echo "  sudo systemctl edit --full k3s"
echo "  Add '--disable-network-policy' to ExecStart line"
echo "  sudo systemctl daemon-reload && sudo systemctl restart k3s"
