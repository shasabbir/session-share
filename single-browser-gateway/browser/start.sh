#!/bin/bash
set -e

RESOLUTION="${RESOLUTION:-1920x1080}"
TARGET_URL="${TARGET_URL:-https://example.com}"
BROWSER_MODE="${BROWSER_MODE:-app}"

echo "================================================="
echo "   Single Website Cloud Browser Gateway"
echo "================================================="
echo "Target URL:  ${TARGET_URL}"
echo "Resolution:  ${RESOLUTION}"
echo "Mode:        ${BROWSER_MODE}"
echo "================================================="

# Remove leftover X server locks if container was forcefully restarted
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

# 1. Start Xvfb (Virtual Framebuffer Display :99)
echo "[1/4] Starting virtual display (Xvfb)..."
Xvfb :99 -screen 0 "${RESOLUTION}x24" -ac -nolisten tcp &
XVFB_PID=$!
export DISPLAY=:99
sleep 1

# 2. Start Openbox minimal window manager
echo "[2/4] Starting minimal window manager (Openbox)..."
openbox &

# 3. Start x11vnc server (RFB port 5900 on localhost)
echo "[3/4] Starting VNC server (x11vnc)..."
x11vnc -display :99 -forever -shared -nopw -rfbport 5900 -listen 127.0.0.1 -quiet &

# 4. Start websockify for noVNC web access (Port 6080)
echo "[4/4] Starting WebSocket to VNC bridge (websockify)..."
websockify --web /usr/share/novnc 6080 127.0.0.1:5900 &

# Parse window resolution width and height
WIDTH=$(echo "${RESOLUTION}" | cut -d'x' -f1)
HEIGHT=$(echo "${RESOLUTION}" | cut -d'x' -f2)

EXTRA_FLAGS=""
if [ "${BROWSER_MODE}" = "kiosk" ]; then
    EXTRA_FLAGS="--kiosk"
fi

echo "Launching Chromium in dedicated mode..."

# Chromium flags designed for single-site appliance operation:
# - '--app=...' removes URL address bar, tabs, and forward/backward buttons
# - '--user-data-dir=/profile' persists cookies, logins, and local storage
# - '--disable-session-crashed-bubble' prevents annoying crash prompts on restart
exec chromium \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --no-first-run \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --disable-save-password-bubble \
    --check-for-update-interval=31536000 \
    --user-data-dir=/profile \
    --window-position=0,0 \
    --window-size=${WIDTH},${HEIGHT} \
    --app="${TARGET_URL}" \
    ${EXTRA_FLAGS}
