# Troubleshooting Guide

This guide covers common issues encountered when deploying and running the Single Website Cloud Browser Gateway.

---

### 1. noVNC Shows "Failed to connect to server" or Hangs on "Connecting..."
* **Cause 1: Missing Apache WebSocket Modules**
  Run:
  ```bash
  sudo a2enmod proxy_wstunnel rewrite
  sudo systemctl restart apache2
  ```
* **Cause 2: Container Not Running**
  Verify the container is healthy:
  ```bash
  docker compose ps
  docker compose logs -f browser
  ```
* **Cause 3: WebSocket Subpath Disconnect**
  Make sure your URL includes the autoconnect parameters:
  `http://SERVER_IP/example.com/vnc.html?autoconnect=true&resize=remote&path=example.com/websockify`
  Our Apache rewrite rule does this automatically, but if you bypassed Apache and hit port 6080 directly, the path parameter is required.

---

### 2. Chromium Crashes with "Aw, Snap!" or Black Screen
* **Cause: Exhausted Shared Memory (`/dev/shm`)**
  Modern browsers consume substantial shared memory for tab rendering and hardware acceleration emulation.
  **Fix**:
  Ensure `docker-compose.yml` contains:
  ```yaml
  shm_size: '2gb'
  volumes:
    - /dev/shm:/dev/shm
  ```
  If your host system has limited RAM, set `shm_size: '1gb'`.

---

### 3. "Snap is not supported in this container" (If using Ubuntu base)
* **Cause**: On Ubuntu 22.04, `apt-get install chromium-browser` is a wrapper that triggers `snap install chromium`. Snapd cannot run in standard Docker containers without systemd privileges.
* **Fix**:
  Our Dockerfile uses `debian:bookworm-slim`, which maintains the official native `.deb` package of Chromium without snap. If you must use Ubuntu base, you must add the Debian upstream pin or Google Chrome official deb package instead of `chromium-browser`.

---

### 4. Display Resolution Mismatch (Window Too Small or Scrolled)
* **Fix**:
  Change the `RESOLUTION` variable in your `.env` file to match your primary viewing screen:
  ```env
  RESOLUTION=1920x1080
  # Or for 16:10 laptops / tablets:
  # RESOLUTION=1680x1050
  # RESOLUTION=1280x800
  ```
  Then restart the container:
  ```bash
  docker compose up -d --force-recreate
  ```
  In noVNC, click the left gear icon (settings) and set **Scaling Mode** to `Remote Resizing` or `Local Scaling`.

---

### 5. Apache Gives 401 Unauthorized Repeatedly
* **Cause**: The password was mistyped or `/etc/apache2/.htpasswd` has bad permissions.
* **Fix**:
  Re-generate the user password:
  ```bash
  sudo htpasswd -c /etc/apache2/.htpasswd browseradmin
  sudo chown www-data:www-data /etc/apache2/.htpasswd
  sudo chmod 640 /etc/apache2/.htpasswd
  ```

---

### 6. Profile Permissions Error During Reset
* **Cause**: Chromium created files owned by `root` or an internal UID inside `data/chromium-profile`.
* **Fix**:
  ```bash
  sudo chmod -R 777 data/chromium-profile
  ```
  The `reset-session.sh` script handles this automatically.

---

### 7. View Live Logs for Debugging
- **Container standard output (Xvfb, x11vnc, Chromium)**:
  ```bash
  docker compose logs -f browser
  ```
- **Apache access & error logs**:
  ```bash
  tail -f /var/log/apache2/cloud_browser_error.log
  tail -f /var/log/apache2/cloud_browser_access.log
  ```
- **Admin server logs**:
  ```bash
  journalctl -u browser-admin.service -f
  ```
