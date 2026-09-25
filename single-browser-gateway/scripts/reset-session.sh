#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "   Chromium Session Reset Utility"
echo "=========================================="

cd "$PROJECT_ROOT"

TARGET="${1:-all}" # 'all', 'desktop', or 'mobile'

if [ "$TARGET" = "desktop" ] || [ "$TARGET" = "all" ]; then
    echo "[*] Resetting Desktop session..."
    docker compose stop browser-desktop 2>/dev/null || true
    rm -rf data/profile-desktop/*
    mkdir -p data/profile-desktop
    chmod -R 777 data/profile-desktop
    docker compose start browser-desktop 2>/dev/null || true
fi

if [ "$TARGET" = "mobile" ] || [ "$TARGET" = "all" ]; then
    echo "[*] Resetting Mobile session..."
    docker compose stop browser-mobile 2>/dev/null || true
    rm -rf data/profile-mobile/*
    mkdir -p data/profile-mobile
    chmod -R 777 data/profile-mobile
    docker compose start browser-mobile 2>/dev/null || true
fi

echo "=========================================="
echo "[SUCCESS] Session reset complete for target: ${TARGET}!"
echo "Browser instances restarted with fresh states."
echo "=========================================="
