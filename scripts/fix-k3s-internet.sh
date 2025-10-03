#!/bin/bash
# Fix K3s pod internet connectivity via masquerading

echo "=========================================="
echo "K3s Internet Connectivity Fix"
echo "=========================================="
echo ""

echo "=== Step 1: Get K3s configuration ==="
# Get pod CIDR
POD_CIDR=$(kubectl cluster-info dump 2>/dev/null | grep -oP 'cluster-cidr[=:]\K[0-9./]+' | head -1)
if [ -z "$POD_CIDR" ]; then
  POD_CIDR="10.42.0.0/16"  # K3s default
  echo "Using K3s default pod CIDR: $POD_CIDR"
else
  echo "Pod CIDR detected: $POD_CIDR"
fi

# Get service CIDR
SERVICE_CIDR=$(kubectl cluster-info dump 2>/dev/null | grep -oP 'service-cluster-ip-range[=:]\K[0-9./]+' | head -1)
if [ -z "$SERVICE_CIDR" ]; then
  SERVICE_CIDR="10.43.0.0/16"  # K3s default
  echo "Using K3s default service CIDR: $SERVICE_CIDR"
else
  echo "Service CIDR detected: $SERVICE_CIDR"
fi

# Get primary network interface
PRIMARY_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Primary interface: $PRIMARY_IFACE"
echo ""

echo "=== Step 2: Check existing masquerading rules ==="
echo "Current MASQUERADE rules:"
sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE || echo "No MASQUERADE rules found"
echo ""

echo "=== Step 3: Add masquerading for pod CIDR ==="
# Check if rule already exists
if sudo iptables -t nat -C POSTROUTING -s $POD_CIDR -o $PRIMARY_IFACE -j MASQUERADE 2>/dev/null; then
  echo "✓ MASQUERADE rule already exists for $POD_CIDR"
else
  echo "Adding MASQUERADE rule for $POD_CIDR..."
  sudo iptables -t nat -A POSTROUTING -s $POD_CIDR -o $PRIMARY_IFACE -j MASQUERADE
  echo "✅ MASQUERADE rule added"
fi
echo ""

echo "=== Step 4: Enable IP forwarding (if not enabled) ==="
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
  echo "✓ IP forwarding already enabled"
else
  echo "Enabling IP forwarding..."
  sudo sysctl -w net.ipv4.ip_forward=1
  # Make permanent
  echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
  echo "✅ IP forwarding enabled"
fi
echo ""

echo "=== Step 5: Make iptables rules persistent ==="
if command -v netfilter-persistent &> /dev/null; then
  echo "Saving iptables rules with netfilter-persistent..."
  sudo netfilter-persistent save
elif command -v iptables-save &> /dev/null; then
  echo "Saving iptables rules to /etc/iptables/rules.v4..."
  sudo mkdir -p /etc/iptables
  sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
fi
echo ""

echo "=== Step 6: Verify new rules ==="
echo "POSTROUTING MASQUERADE rules:"
sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE
echo ""

echo "=== Step 7: Test internet from pod ==="
echo "Testing GitHub connectivity from pod..."
kubectl run test-internet-fixed --rm -i --restart=Never --image=curlimages/curl:latest -- \
  curl -I -m 10 https://github.com 2>&1 | head -5
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "If the test above shows HTTP/2 200, internet access is working!"
echo "If it still times out, check:"
echo "  1. Hetzner Cloud Firewall settings"
echo "  2. K3s service configuration: systemctl cat k3s"
echo "  3. Any additional firewall rules: sudo iptables -L -n -v"
