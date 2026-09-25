#!/bin/bash
set -e

# Single Website Cloud Browser Gateway - One-Step Installer
# OS Target: Ubuntu 22.04 / 24.04 LTS
# Target Port: 5151

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run this installer as root (e.g. sudo bash install.sh)"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "==========================================================="
echo "   Single Website Cloud Browser Gateway Installer"
echo "   (Port 5151 | Always-On | Dual Responsive Architecture)"
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

# Ensure Docker uses reliable public DNS
if [ ! -f /etc/docker/daemon.json ]; then
    echo '{"dns": ["8.8.8.8", "1.1.1.1"]}' > /etc/docker/daemon.json
    systemctl restart docker
fi

systemctl enable --now docker

# 3. Install Apache2 and utilities
echo "[3/7] Installing Apache2 and authentication utilities..."
apt-get install -y apache2 apache2-utils python3

systemctl enable apache2

# 4. Enable required Apache modules
echo "[4/7] Enabling Apache proxy, rewrite, and websocket modules..."
a2enmod proxy proxy_http proxy_wstunnel rewrite headers
systemctl restart apache2

# 5. Create HTTP Basic Auth credentials
echo "[5/7] Configuring authentication (.htpasswd)..."
ADMIN_USER="${ADMIN_USER:-browseradmin}"

# Ensure .htpasswd exists and has the admin user
if [ -f "/etc/apache2/.htpasswd" ] && grep -q "^${ADMIN_USER}:" /etc/apache2/.htpasswd; then
    echo "Found valid credentials for '${ADMIN_USER}' in /etc/apache2/.htpasswd."
else
    echo "Configuring credentials for user: ${ADMIN_USER}"
    if [ -n "$ADMIN_PASS" ]; then
        htpasswd -bc /etc/apache2/.htpasswd "$ADMIN_USER" "$ADMIN_PASS"
    else
        while true; do
            echo "Please enter a password for user '${ADMIN_USER}':"
            if htpasswd -c /etc/apache2/.htpasswd "$ADMIN_USER"; then
                echo "Credentials saved successfully."
                break
            else
                echo "[!] Password verification failed. Please try again."
            fi
        done
    fi
fi

# 6. Configure Apache Port 5151 & Site
echo "[6/7] Deploying Apache reverse proxy on port 5151..."
if ! grep -q "Listen 5151" /etc/apache2/ports.conf; then
    echo "Configuring Apache to listen on port 5151..."
    echo "Listen 5151" >> /etc/apache2/ports.conf
fi

# Allow port 5151 through UFW firewall if active
if command -v ufw &> /dev/null; then
    echo "Opening firewall port 5151/tcp..."
    ufw allow 5151/tcp 2>/dev/null || true
fi

cp "${PROJECT_DIR}/apache/browser.conf" /etc/apache2/sites-available/browser.conf

a2dissite 000-default.conf 2>/dev/null || true
a2ensite browser.conf

apache2ctl configtest
systemctl restart apache2

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

# Sync host's verified working apt sources into container context
if [ -f "/etc/apt/sources.list.d/ubuntu.sources" ]; then
    echo "Syncing host apt sources to build context..."
    cp /etc/apt/sources.list.d/ubuntu.sources "${PROJECT_DIR}/browser/host.sources"
elif [ -f "/etc/apt/sources.list" ]; then
    echo "Syncing host apt sources to build context..."
    cp /etc/apt/sources.list "${PROJECT_DIR}/browser/host.sources"
fi

# Build and start containers with restart: always
docker compose build --no-cache
docker compose up -d

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "==========================================================="
echo "   INSTALLATION COMPLETE (ALWAYS-ON RUNNING)!"
echo "==========================================================="
echo "Access on Port 5151:"
echo "   Smart Gateway: http://${SERVER_IP}:5151/example.com"
echo "   Desktop View:  http://${SERVER_IP}:5151/desktop"
echo "   Mobile View:   http://${SERVER_IP}:5151/mobile"
echo "   Admin Panel:   http://${SERVER_IP}:5151/admin"
echo ""
echo "Username: ${ADMIN_USER}"
echo "Password: (the password you configured)"
echo "==========================================================="
