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
echo "   Browser Profiles Restore Utility"
echo "=========================================="
echo "Restoring from: $BACKUP_FILE"

echo "[1/4] Stopping browser containers..."
docker compose stop browser-desktop browser-mobile 2>/dev/null || true

echo "[2/4] Clearing existing profiles..."
rm -rf data/profile-desktop/* data/profile-mobile/*
mkdir -p data/profile-desktop data/profile-mobile

echo "[3/4] Extracting backup archive..."
tar -xzf "$BACKUP_FILE" -C data/
chmod -R 777 data/

echo "[4/4] Starting browser containers..."
docker compose start browser-desktop browser-mobile 2>/dev/null || true

echo "=========================================="
echo "[SUCCESS] Restore complete!"
echo "Restored from: $(basename "$BACKUP_FILE")"
echo "=========================================="
