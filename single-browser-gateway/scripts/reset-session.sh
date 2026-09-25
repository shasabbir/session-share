#!/bin/bash
set -e

# Resolve project root directory (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "   Chromium Session Reset Utility"
echo "=========================================="

cd "$PROJECT_ROOT"

if [ ! -d "data/chromium-profile" ]; then
    echo "[!] Profile directory data/chromium-profile does not exist yet."
    exit 0
fi

echo "[1/3] Stopping browser container..."
docker compose stop browser

echo "[2/3] Purging persistent browser session data..."
# Wipe profile contents (cookies, logins, cache)
rm -rf data/chromium-profile/*
# Re-ensure directory permissions
mkdir -p data/chromium-profile
chmod 777 data/chromium-profile

echo "[3/3] Restarting browser with fresh profile..."
docker compose start browser

echo "=========================================="
echo "[SUCCESS] Session reset complete!"
echo "Chromium is now running with a fresh state."
echo "=========================================="
