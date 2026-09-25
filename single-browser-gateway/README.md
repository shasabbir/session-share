# Single Website Cloud Browser Gateway

A lightweight, self-hosted remote browser appliance running on Ubuntu 22.04. It isolates and serves a single dedicated target website over a secure web stream (noVNC + Chromium) accessible from any mobile or desktop browser.

---

## Architecture

```
[ User Device: Phone / Laptop / Tablet ]
                 │
                 │ HTTP / WebSocket (Basic Auth: browseradmin)
                 ▼
     [ Apache2 Reverse Proxy ]
     ├── /example.com   --> ws://127.0.0.1:6080 (noVNC HTML5 client)
     └── /admin         --> http://127.0.0.1:8088 (Micro Admin UI)
                 │
                 ▼ (Localhost only)
   [ Docker: cloud-browser container ]
   ├── websockify (Port 6080)
   ├── x11vnc (Port 5900)
   ├── Openbox (Minimal window manager)
   ├── Xvfb (Virtual display :99)
   └── Chromium (--app=TARGET_URL)
                 │
                 ▼ (Volume Mount)
     [ /data/chromium-profile ] (Persistent sessions, logins, cookies)
```

---

## Key Design Improvements Over Standard Setup

1. **No Desktop Bloat (Zero XFCE)**: Instead of installing an entire desktop environment with menus, taskbars, and wallpapers, we use `Openbox` or pure kiosk framing. Saves ~600MB of RAM, shrinks the container image, and prevents users from escaping to a desktop shell.
2. **Eliminated the Ubuntu Snap Trap**: In standard Ubuntu 22.04, `apt-get install chromium-browser` is a wrapper requiring `snapd`, which fails inside Docker. We use `debian:bookworm-slim` as the container base to install the official, native deb package directly without snap overhead.
3. **Seamless Subpath Auto-Connect**: Reverse-proxying noVNC under a subpath like `/example.com/` often causes broken asset paths or manual "Connect" button prompts. Our Apache configuration includes an automatic rewrite that routes to `vnc.html` with `autoconnect=true`, `resize=remote`, and explicit websocket path forwarding.
4. **Zero-Dependency Admin Server**: Instead of maintaining a complex Node.js or Flask backend with Docker socket exposure, the admin interface is a single-file Python script (~100 lines) using standard library modules already present on Ubuntu.
5. **Strict Localhost Binding**: Port `6080` binds strictly to `127.0.0.1`, guaranteeing no unauthorized external bypass around Apache's Basic Authentication.

---

## Directory Structure

```
single-browser-gateway/
├── docker-compose.yml          # Container configuration & resource limits
├── .env.example                # Target URL & resolution template
├── install.sh                  # One-step automated Ubuntu 22.04 installer
├── browser/
│   ├── Dockerfile              # Lightweight Debian Bookworm + Chromium + noVNC
│   └── start.sh                # Virtual display and browser launch script
├── apache/
│   └── browser.conf            # Apache2 reverse proxy & WebSocket configuration
├── admin/
│   ├── admin_server.py         # Zero-dependency admin web UI & API
│   └── browser-admin.service   # Systemd service unit for admin server
├── scripts/
│   ├── reset-session.sh        # Purges profile data and restarts browser
│   ├── backup.sh               # Consistent snapshot generator
│   └── restore.sh              # Profile restoration utility
└── data/
    └── chromium-profile/       # Persistent user data (cookies, storage, logins)
```

---

## Quick Start (Automated Deployment)

### 1. Clone or Copy Files to Server
```bash
sudo git clone <your-repo> /opt/single-browser-gateway
cd /opt/single-browser-gateway
```

### 2. Configure Your Target Website
Copy `.env.example` to `.env` and set your desired website:
```bash
cp .env.example .env
nano .env
```
Example `.env`:
```env
TARGET_URL=https://target-internal-portal.com
RESOLUTION=1920x1080
BROWSER_MODE=app
```

### 3. Run the Installer
```bash
sudo bash install.sh
```
The installer will:
- Install Docker, Docker Compose, and Apache2.
- Prompt you to set a password for the `browseradmin` user.
- Enable Apache modules (`proxy`, `proxy_http`, `proxy_wstunnel`, `rewrite`, `headers`).
- Configure persistent directories and permissions.
- Build and launch the container.

---

## Accessing the Gateway

- **Browser Gateway**: `http://YOUR_SERVER_IP/example.com`
- **Admin Dashboard**: `http://YOUR_SERVER_IP/admin`
- **Username**: `browseradmin`
- **Password**: *(The password created during installation)*

---

## Management & Operations

### Reset Session (Logout & Fresh Profile)
To log out of the target website and reset the browser to a factory-clean state:
```bash
sudo bash scripts/reset-session.sh
```
*Or click the **Reset Session** button in `http://YOUR_SERVER_IP/admin`.*

### Back Up Browser Profile
To create a timestamped backup of all cookies, sessions, and local storage:
```bash
sudo bash scripts/backup.sh
```
Backups are saved to `backups/chromium-profile-YYYYMMDD_HHMMSS.tar.gz`.

### Restore Browser Profile
To restore from a previous backup:
```bash
sudo bash scripts/restore.sh backups/chromium-profile-20260925_120000.tar.gz
```

### Restart Browser Container
```bash
docker compose restart browser
```

---

## Security Recommendations

1. **Enable HTTPS (Let's Encrypt / Certbot)**:
   In production, protect your credentials and browser stream with TLS:
   ```bash
   sudo apt-get install -y certbot python3-certbot-apache
   sudo certbot --apache -d yourdomain.com
   ```
2. **Change Default Credentials**:
   To change or add passwords:
   ```bash
   sudo htpasswd /etc/apache2/.htpasswd browseradmin
   ```
3. **Firewall (UFW)**:
   Ensure only HTTP/HTTPS and SSH are open:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 22/tcp
   sudo ufw enable
   ```
