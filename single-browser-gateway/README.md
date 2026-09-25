# Single Website Cloud Browser Gateway

A lightweight, self-hosted remote browser appliance running on Ubuntu 22.04. It isolates and serves a single dedicated target website over a secure web stream (noVNC + Chromium) with native **responsive UI support for both PC and mobile devices simultaneously**.

---

## Dual Desktop + Mobile Architecture

```
[ User Device: Phone / Tablet ]         [ User Device: PC / Laptop ]
               │                                      │
               │ (Mobile User-Agent)                  │ (Desktop User-Agent)
               └──────────────────┬───────────────────┘
                                  │
                                  ▼
                    [ Apache2 Reverse Proxy ]
                    ├── Auto-detects device & routes:
                    │   • Mobile User-Agent   --> /mobile (Port 6081)
                    │   • Desktop User-Agent  --> /desktop (Port 6080)
                    └── /admin                --> Admin Dashboard (Port 8088)
                                  │
               ┌──────────────────┴──────────────────┐
               ▼ (Port 6080)                         ▼ (Port 6081)
     [ cloud-browser-desktop ]             [ cloud-browser-mobile ]
     • Resolution: 1920x1080               • Resolution: 412x915 (Portrait)
     • Desktop Chromium                    • Mobile Touch & Mobile User-Agent
     • Triggers Desktop Responsive UI      • Triggers Mobile Responsive UI
               │                                     │
               ▼ (Volume Mount)                      ▼ (Volume Mount)
     [ /data/profile-desktop ]             [ /data/profile-mobile ]
```

---

## Why This Architecture Solves PC + Phone Concurrency

1. **Native Responsive Viewports**:
   - The desktop instance runs at **1920x1080**, ensuring the target website loads full desktop navigation, tables, and multi-column sidebars.
   - The mobile instance runs at **412x915** (portrait) with mobile user-agent and touch emulation enabled, ensuring the website loads bottom navigation, hamburger menus, and touch-sized buttons.
2. **True Simultaneous Usage**:
   - Both instances run concurrently. Scrolling or clicking on your phone **will not interfere with or hijack** your PC screen or mouse cursor.
3. **Smart Apache Routing**:
   - Users simply visit `http://SERVER_IP/example.com`.
   - Apache inspects the device `User-Agent`. Phones are seamlessly routed to the mobile container; PCs are routed to the desktop container.
   - Direct URLs are also available: `http://SERVER_IP/desktop` and `http://SERVER_IP/mobile`.
4. **Lightweight & Efficient**:
   - Both containers reuse the exact same lightweight Debian Bookworm image (no XFCE bloat). Total idle RAM for both instances combined is under 600MB.

---

## Quick Start (Automated Deployment)

### 1. Clone on Ubuntu 22.04
```bash
git clone https://github.com/shasabbir/session-share.git
cd session-share/single-browser-gateway
```

### 2. Configure Your Target Website
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
nano .env
```
Set `TARGET_URL` to your website:
```env
TARGET_URL=https://example.com
DESKTOP_RESOLUTION=1920x1080
MOBILE_RESOLUTION=412x915
BROWSER_MODE=app
```

### 3. Run the Installer
```bash
sudo bash install.sh
```

---

## Accessing the Gateway

| Device / Role | URL | Behavior |
| :--- | :--- | :--- |
| **Smart Link (Any Device)** | `http://SERVER_IP/example.com` | Automatically detects PC vs Phone and routes to the correct view. |
| **Explicit Desktop View** | `http://SERVER_IP/desktop` | Forces 1920x1080 desktop layout. |
| **Explicit Mobile View** | `http://SERVER_IP/mobile` | Forces 412x915 mobile touch layout. |
| **Admin Control Panel** | `http://SERVER_IP/admin` | View container status, restart, and reset sessions. |

*Default Username: `browseradmin`*

---

## Operations & Session Management

### Session Reset (Logout)
To wipe persistent logins and start fresh:
```bash
# Reset both desktop and mobile sessions
sudo bash scripts/reset-session.sh

# Or reset individually:
sudo bash scripts/reset-session.sh desktop
sudo bash scripts/reset-session.sh mobile
```
*Or use the **Reset All Sessions** button in `http://SERVER_IP/admin`.*

### Back Up Profiles
```bash
sudo bash scripts/backup.sh
```
Snapshots are archived into `backups/browser-profiles-YYYYMMDD_HHMMSS.tar.gz`.

### Restore Profiles
```bash
sudo bash scripts/restore.sh backups/<archive-name>.tar.gz
```
