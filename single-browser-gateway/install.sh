#!/bin/bash
set -e

# Single Website Cloud Browser Gateway - One-Step Installer
# OS Target: Ubuntu 22.04 LTS

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run this installer as root (e.g. sudo bash install.sh)"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "==========================================================="
echo "   Single Website Cloud Browser Gateway Installer"
echo "   (Dual Desktop + Mobile Responsive Architecture)"
echo "==========================================================="

# 1. Update package lists
echo "[1/7] Updating package index..."
apt-get update -y

# 2. Check and Install Docker & Docker Compose
echo "[2/7] Checking Docker & Docker Compose..."
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

systemctl enable --now docker

# 3. Install Apache2 and utilities
echo "[3/7] Installing Apache2 and authentication utilities..."
apt-get install -y apache2 apache2-utils python3

# 4. Enable required Apache modules
echo "[4/7] Enabling Apache proxy, rewrite, and websocket modules..."
a2enmod proxy proxy_http proxy_wstunnel rewrite headers
systemctl restart apache2

# 5. Create HTTP Basic Auth credentials
echo "[5/7] Configuring authentication (.htpasswd)..."
ADMIN_USER="${ADMIN_USER:-browseradmin}"

if [ -f "/etc/apache2/.htpasswd" ]; then
    echo "Found existing /etc/apache2/.htpasswd. Keeping existing users."
else
    echo "Creating credentials for user: ${ADMIN_USER}"
    if [ -n "$ADMIN_PASS" ]; then
        htpasswd -bc /etc/apache2/.htpasswd "$ADMIN_USER" "$ADMIN_PASS"
    else
        echo "Please enter a password for user '${ADMIN_USER}':"
        htpasswd -c /etc/apache2/.htpasswd "$ADMIN_USER"
    fi
fi

# 6. Setup Apache configuration
echo "[6/7] Deploying Apache reverse proxy configuration..."
cp "${PROJECT_DIR}/apache/browser.conf" /etc/apache2/sites-available/browser.conf

a2dissite 000-default.conf 2>/dev/null || true
a2ensite browser.conf

apache2ctl configtest
systemctl reload apache2

# 7. Setup persistent directories and build containers
echo "[7/7] Initializing persistent storage and building Docker containers..."
mkdir -p "${PROJECT_DIR}/data/profile-desktop"
mkdir -p "${PROJECT_DIR}/data/profile-mobile"
mkdir -p "${PROJECT_DIR}/backups"
chmod -R 777 "${PROJECT_DIR}/data"

# Make helper scripts executable
chmod +x "${PROJECT_DIR}/scripts/"*.sh
chmod +x "${PROJECT_DIR}/browser/start.sh"
chmod +x "${PROJECT_DIR}/admin/admin_server.py"

# Configure .env if not exists
if [ ! -f "${PROJECT_DIR}/.env" ]; then
    cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
fi

# Register admin micro-service in systemd
if [ -f "${PROJECT_DIR}/admin/browser-admin.service" ]; then
    sed -i "s|/opt/single-browser-gateway|${PROJECT_DIR}|g" "${PROJECT_DIR}/admin/browser-admin.service"
    cp "${PROJECT_DIR}/admin/browser-admin.service" /etc/systemd/system/browser-admin.service
    systemctl daemon-reload
    systemctl enable --now browser-admin.service
fi

# Build and start containers
docker compose up -d --build

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "==========================================================="
echo "   INSTALLATION COMPLETE!"
echo "==========================================================="
echo "Auto-detected entry point (PC -> Desktop / Phone -> Mobile):"
echo "   http://${SERVER_IP}/example.com"
echo ""
echo "Direct Links:"
echo "   Desktop View:  http://${SERVER_IP}/desktop"
echo "   Mobile View:   http://${SERVER_IP}/mobile"
echo "   Admin Panel:   http://${SERVER_IP}/admin"
echo ""
echo "Username: ${ADMIN_USER}"
echo "Password: (the password you configured)"
echo "==========================================================="
