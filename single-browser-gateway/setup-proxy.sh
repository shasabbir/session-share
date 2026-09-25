#!/bin/bash
set -e

# ==============================================================================
#   Lightweight Native Proxy Installer (HTTP + SOCKS5)
#   Browse ChatGPT directly from your native PC / Phone browser using your VPS IP
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run this script as root (sudo bash setup-proxy.sh)"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PROXY_PORT="${1:-5150}"
PROXY_USER="${PROXY_USER:-chatgptuser}"
PROXY_PASS="${PROXY_PASS:-$(openssl rand -hex 6 2>/dev/null || echo 'VpsPass982')}"

SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
fi

echo "==========================================================="
echo "   Deploying High-Speed Native Proxy (HTTP & SOCKS5)"
echo "   Server IP: ${SERVER_IP}"
echo "   Port:      ${PROXY_PORT}"
echo "==========================================================="

# Allow firewall port if ufw is active
if command -v ufw &>/dev/null; then
    ufw allow ${PROXY_PORT}/tcp 2>/dev/null || true
fi

# Stop existing proxy container if running
docker rm -f vps-native-proxy 2>/dev/null || true

# Run GOST dual HTTP + SOCKS5 proxy container
docker run -d \
  --name vps-native-proxy \
  --restart always \
  -p ${PROXY_PORT}:${PROXY_PORT} \
  ginuerzh/gost:latest \
  -L "http://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}" \
  -L "socks5://${PROXY_USER}:${PROXY_PASS}@:${PROXY_PORT}"

echo ""
echo "==========================================================="
echo "   PROXY IS NOW ACTIVE! (ZERO VNC / ZERO LAG)"
echo "==========================================================="
echo ""
echo "Connection Details:"
echo "   Proxy Type:   HTTP or SOCKS5"
echo "   Server / Host: ${SERVER_IP}"
echo "   Port:          ${PROXY_PORT}"
echo "   Username:      ${PROXY_USER}"
echo "   Password:      ${PROXY_PASS}"
echo ""
echo "-----------------------------------------------------------"
echo "HOW TO USE ON IPHONE / ANDROID (1 Minute Setup):"
echo "-----------------------------------------------------------"
echo "1. Go to your Phone Settings -> Wi-Fi -> tap your connected Wi-Fi."
echo "2. Scroll down to 'Configure Proxy' (or 'Proxy') -> select 'Manual'."
echo "3. Enter:"
echo "      Server:   ${SERVER_IP}"
echo "      Port:     ${PROXY_PORT}"
echo "      Auth:     Enable"
echo "      Username: ${PROXY_USER}"
echo "      Password: ${PROXY_PASS}"
echo "4. Open Safari / Chrome or the official ChatGPT app on your phone."
echo "   All traffic now exits from ${SERVER_IP} with 100% native phone UI!"
echo ""
echo "-----------------------------------------------------------"
echo "HOW TO USE ON PC (CHROME / EDGE / FIREFOX):"
echo "-----------------------------------------------------------"
echo "Option A (Free Browser Extension like Proxy SwitchyOmega or FoxyProxy):"
echo "   - Add proxy: HTTP or SOCKS5 -> ${SERVER_IP}:${PROXY_PORT}"
echo "   - Set username & password when prompted."
echo ""
echo "Option B (Windows Settings):"
echo "   - Settings -> Network & Internet -> Proxy -> Set Manual Proxy Server:"
echo "     Address: ${SERVER_IP}, Port: ${PROXY_PORT}"
echo ""
echo "==========================================================="
