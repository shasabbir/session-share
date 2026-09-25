#!/bin/bash
set -e

# Instant Apache Port 5151 Fixer
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run as root: sudo bash fix-apache.sh"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "   Fixing Apache Port 5151 Configuration"
echo "=========================================="

# 1. Ensure Listen 5151 in ports.conf
if ! grep -q "Listen 5151" /etc/apache2/ports.conf; then
    echo "[1/5] Adding Listen 5151 to /etc/apache2/ports.conf..."
    echo "Listen 5151" >> /etc/apache2/ports.conf
else
    echo "[1/5] Listen 5151 is already in /etc/apache2/ports.conf."
fi

# 2. Deploy 000-browser.conf (prefix 000- ensures it loads first before robobari)
echo "[2/5] Deploying /etc/apache2/sites-available/000-browser.conf..."
cp "${PROJECT_DIR}/apache/browser.conf" /etc/apache2/sites-available/000-browser.conf
mkdir -p /var/www/html
cp "${PROJECT_DIR}/apache/index.html" /var/www/html/index.html

# 3. Enable 000-browser.conf and disable any stale browser.conf
echo "[3/5] Activating 000-browser.conf..."
a2dissite browser.conf 2>/dev/null || true
a2ensite 000-browser.conf

# 4. Test configuration
echo "[4/5] Testing Apache configuration..."
apache2ctl configtest

# 5. Restart Apache
echo "[5/5] Restarting Apache service..."
systemctl restart apache2

echo "=========================================="
echo "[SUCCESS] Apache VirtualHost Table:"
apache2ctl -S | grep -E "5151|port" || apache2ctl -S
echo "=========================================="
