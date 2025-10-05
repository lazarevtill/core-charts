#!/bin/bash

echo "Testing KubeSphere chart download..."
echo ""

# Test 1: Direct curl
echo "Test 1: Downloading with curl..."
curl -L -v -o /tmp/test-ks-core.tgz https://charts.kubesphere.io/main/ks-core-1.1.4.tgz 2>&1 | head -30
echo ""
file /tmp/test-ks-core.tgz
echo ""
hexdump -C /tmp/test-ks-core.tgz | head -5
echo ""

# Test 2: Try wget
echo "Test 2: Downloading with wget..."
wget -O /tmp/test-ks-core-wget.tgz https://charts.kubesphere.io/main/ks-core-1.1.4.tgz 2>&1 | head -20
file /tmp/test-ks-core-wget.tgz
echo ""

# Test 3: Check what Helm actually tries
echo "Test 3: Helm fetch test..."
helm fetch https://charts.kubesphere.io/main/ks-core-1.1.4.tgz --destination /tmp/ 2>&1
ls -lah /tmp/ks-core-1.1.4.tgz
file /tmp/ks-core-1.1.4.tgz

# Cleanup
rm -f /tmp/test-ks-core*.tgz /tmp/ks-core-1.1.4.tgz
