#!/bin/bash

echo "=========================================="
echo "   ChatGPT & Network Route Diagnostic"
echo "=========================================="

echo ""
echo "[1] Checking DNS resolution inside container:"
docker exec cloud-browser-desktop nslookup chatgpt.com 2>&1 || true

echo ""
echo "[2] Checking DNS resolution on host:"
nslookup chatgpt.com 2>&1 || true

echo ""
echo "[3] Checking /etc/hosts for overrides:"
grep -iE "chatgpt|robobari" /etc/hosts || echo "No overrides found in /etc/hosts."

echo ""
echo "[4] Checking iptables NAT redirection rules:"
iptables -t nat -S 2>&1 | grep -iE "443|28443|28080|REDIRECT|DNAT" || echo "No NAT redirection rules found."

echo ""
echo "[5] Testing HTTPS handshake from inside container:"
docker exec cloud-browser-desktop curl -Iv https://chatgpt.com 2>&1 | head -n 25 || true

echo ""
echo "=========================================="
