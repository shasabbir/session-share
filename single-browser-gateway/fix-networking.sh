#!/bin/bash
set -e

echo "==========================================================="
echo "   Fixing Network Routing & Port 443 Redirection Conflict"
echo "==========================================================="

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run this script as root (sudo bash fix-networking.sh)"
    exit 1
fi

SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
fi

echo "[*] Server IP detected: ${SERVER_IP}"

echo ""
echo "[1/5] Checking /etc/hosts for conflicting entries..."
if grep -iE "chatgpt|openai" /etc/hosts >/dev/null 2>&1; then
    echo "[!] Removing conflicting chatgpt entries from /etc/hosts..."
    sed -i '/chatgpt/Id' /etc/hosts
    sed -i '/openai/Id' /etc/hosts
else
    echo "[-] /etc/hosts is clean."
fi

echo ""
echo "[2/5] Current iptables NAT rules on port 80/443:"
iptables -t nat -S | grep -E "443|28443|80|28080" || echo "None found."

echo ""
echo "[3/5] Fixing rogue iptables redirection rules..."
# Delete any catch-all PREROUTING rules that redirect ALL port 443 / 80 traffic
# regardless of destination (which hijacks Docker outbound connections)

# Loop to remove all unqualified port 443 redirects
while iptables -t nat -D PREROUTING -p tcp -m tcp --dport 443 -j REDIRECT --to-ports 28443 2>/dev/null; do
    echo "[-] Removed catch-all PREROUTING redirect for port 443 -> 28443"
done
while iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-ports 28443 2>/dev/null; do
    echo "[-] Removed catch-all PREROUTING redirect for port 443 -> 28443"
done

# Loop to remove all unqualified port 80 redirects
while iptables -t nat -D PREROUTING -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 28080 2>/dev/null; do
    echo "[-] Removed catch-all PREROUTING redirect for port 80 -> 28080"
done
while iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 28080 2>/dev/null; do
    echo "[-] Removed catch-all PREROUTING redirect for port 80 -> 28080"
done

# Also check OUTPUT chain if someone redirected from localhost
while iptables -t nat -D OUTPUT -p tcp -m tcp --dport 443 -j REDIRECT --to-ports 28443 2>/dev/null; do
    echo "[-] Removed catch-all OUTPUT redirect for port 443 -> 28443"
done
while iptables -t nat -D OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 28443 2>/dev/null; do
    echo "[-] Removed catch-all OUTPUT redirect for port 443 -> 28443"
done

# Now add SAFE redirection rules: ONLY incoming traffic destined for the SERVER IP
# gets redirected to 28443 / 28080 (so robobari.com still works 100%, but Docker is not touched)
if [ -n "$SERVER_IP" ]; then
    if ! iptables -t nat -C PREROUTING -d "${SERVER_IP}" -p tcp --dport 443 -j REDIRECT --to-ports 28443 2>/dev/null; then
        iptables -t nat -A PREROUTING -d "${SERVER_IP}" -p tcp --dport 443 -j REDIRECT --to-ports 28443
        echo "[+] Added safe port 443 -> 28443 redirect specifically for ${SERVER_IP}"
    fi
    if ! iptables -t nat -C PREROUTING -d "${SERVER_IP}" -p tcp --dport 80 -j REDIRECT --to-ports 28080 2>/dev/null; then
        iptables -t nat -A PREROUTING -d "${SERVER_IP}" -p tcp --dport 80 -j REDIRECT --to-ports 28080
        echo "[+] Added safe port 80 -> 28080 redirect specifically for ${SERVER_IP}"
    fi
fi

# Persist iptables rules if tools exist
if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save 2>/dev/null || true
elif [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

echo ""
echo "[4/5] Testing HTTPS handshake to chatgpt.com from container..."
CONTAINER_TEST=$(docker exec cloud-browser-desktop curl -Iv https://chatgpt.com 2>&1 | head -n 15 || true)
echo "${CONTAINER_TEST}"

if echo "${CONTAINER_TEST}" | grep -qi "robobari"; then
    echo "[!] WARNING: Traffic is still hitting robobari! Additional iptables rules may exist."
    echo "[!] Please run: sudo iptables -t nat -S"
else
    echo "[OK] Successfully connected to OpenAI/ChatGPT directly!"
fi

echo ""
echo "[5/5] Restarting browser containers with fresh state..."
docker compose restart browser-desktop browser-mobile 2>/dev/null || docker restart cloud-browser-desktop cloud-browser-mobile 2>/dev/null || true

echo ""
echo "==========================================================="
echo "   DONE! Now refresh your browser at:"
echo "   http://${SERVER_IP}:5151/www.chatgpt.com"
echo "==========================================================="
