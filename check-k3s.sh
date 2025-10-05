#!/bin/bash

# K3s Health Check and Repair Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Checking K3s status...${NC}"
echo ""

# Check if K3s is installed
if ! command -v k3s &>/dev/null; then
    echo -e "${RED}ERROR: K3s is not installed!${NC}"
    echo "Install K3s first with:"
    echo "  curl -sfL https://get.k3s.io | sh -"
    exit 1
fi

# Check K3s service status
echo "K3s service status:"
systemctl status k3s --no-pager || true
echo ""

# Check if K3s is running
if systemctl is-active --quiet k3s; then
    echo -e "${GREEN}✓ K3s service is running${NC}"
else
    echo -e "${RED}✗ K3s service is not running${NC}"
    echo ""
    echo "Attempting to start K3s..."
    systemctl start k3s
    sleep 10

    if systemctl is-active --quiet k3s; then
        echo -e "${GREEN}✓ K3s service started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start K3s${NC}"
        echo ""
        echo "Check logs:"
        journalctl -u k3s -n 50 --no-pager
        exit 1
    fi
fi

echo ""
echo "Waiting for K3s to be ready..."
sleep 5

# Check kubectl connectivity
if kubectl version --short &>/dev/null; then
    echo -e "${GREEN}✓ kubectl is working${NC}"
else
    echo -e "${RED}✗ kubectl is not working${NC}"
    echo ""
    echo "Checking KUBECONFIG..."
    echo "KUBECONFIG: ${KUBECONFIG:-not set}"
    echo ""

    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        echo "Setting KUBECONFIG..."
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

        if kubectl version --short &>/dev/null; then
            echo -e "${GREEN}✓ kubectl is now working${NC}"
            echo ""
            echo "Add this to your ~/.bashrc:"
            echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
        else
            echo -e "${RED}✗ kubectl still not working${NC}"
            exit 1
        fi
    else
        echo -e "${RED}K3s config file not found at /etc/rancher/k3s/k3s.yaml${NC}"
        exit 1
    fi
fi

echo ""
echo "K3s cluster info:"
kubectl cluster-info
echo ""

echo "Node status:"
kubectl get nodes
echo ""

echo "System pods:"
kubectl get pods -n kube-system
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  K3s is healthy and ready!                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "You can now run: bash nuclear-install.sh"
