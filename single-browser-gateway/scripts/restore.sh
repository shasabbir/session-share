#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <path-to-backup.tar.gz>"
    echo "Available backups in backups/:"
    ls -lh backups/*.tar.gz 2>/dev/null || echo "  (no backups found)"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "[ERROR] Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "=========================================="
echo "   Chromium Profile Restore Utility"
echo "=========================================="
echo "Restoring from: $BACKUP_FILE"

echo "[1/4] Stopping browser container..."
docker compose stop browser

echo "[2/4] Clearing existing profile..."
rm -rf data/chromium-profile/*
mkdir -p data/chromium-profile

echo "[3/4] Extracting backup archive..."
tar -xzf "$BACKUP_FILE" -C data/chromium-profile/
chmod -R 777 data/chromium-profile

echo "[4/4] Starting browser container..."
docker compose start browser

echo "=========================================="
echo "[SUCCESS] Restore complete!"
echo "Browser restored to state from: $(basename "$BACKUP_FILE")"
echo "=========================================="
