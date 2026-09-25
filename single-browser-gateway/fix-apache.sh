#!/bin/bash
set -e

# Instant Apache Port 5151 Fixer & Diagnostic
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run as root: sudo bash fix-apache.sh"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "   Fixing & Diagnosing Port 5151 Gateway"
echo "=========================================="

# 1. Ensure Listen 5151 in ports.conf
echo "[1/6] Checking /etc/apache2/ports.conf..."
if ! grep -q "Listen 5151" /etc/apache2/ports.conf; then
    echo "Adding Listen 5151 to ports.conf..."
    echo "Listen 5151" >> /etc/apache2/ports.conf
else
    echo "Listen 5151 is confirmed present."
fi

# 2. Deploy isolated DocumentRoot in /var/www/browser-gateway (completely separates from Robobari)
echo "[2/6] Setting up isolated DocumentRoot in /var/www/browser-gateway..."
mkdir -p /var/www/browser-gateway
cp "${PROJECT_DIR}/apache/index.html" /var/www/browser-gateway/index.html
chmod -R 755 /var/www/browser-gateway

# 3. Deploy 000-browser.conf
echo "[3/6] Deploying /etc/apache2/sites-available/000-browser.conf..."
cp "${PROJECT_DIR}/apache/browser.conf" /etc/apache2/sites-available/000-browser.conf

# 4. Activate 000-browser.conf and deactivate old browser.conf
echo "[4/6] Enabling 000-browser.conf..."
a2dissite browser.conf 2>/dev/null || true
a2ensite 000-browser.conf

# 5. Test configuration and restart Apache
echo "[5/6] Testing and restarting Apache..."
apache2ctl configtest
systemctl restart apache2

# 6. Verify Docker containers are up
echo "[6/6] Ensuring Docker browser containers are running..."
docker compose up -d

echo ""
echo "=========================================="
echo "   DIAGNOSTIC & VERIFICATION RESULTS"
echo "=========================================="
echo "--> Active Apache VirtualHosts for Port 5151:"
apache2ctl -S 2>&1 | grep -E "5151|port 5151|robobari" || true
echo ""
echo "--> Enabled Apache Sites:"
ls -la /etc/apache2/sites-enabled/
echo ""
echo "--> Docker Container Status:"
docker compose ps
echo "=========================================="
echo "Setup complete! Please test in your browser now."
