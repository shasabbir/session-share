#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

BACKUP_DIR="${PROJECT_ROOT}/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/chromium-profile-${TIMESTAMP}.tar.gz"

echo "=========================================="
echo "   Chromium Profile Backup Utility"
echo "=========================================="
echo "Backup destination: ${BACKUP_FILE}"

if [ ! -d "data/chromium-profile" ] || [ -z "$(ls -A data/chromium-profile 2>/dev/null)" ]; then
    echo "[!] Profile directory is empty. Nothing to backup."
    exit 1
fi

echo "[1/3] Pausing browser container to ensure write consistency..."
docker compose pause browser 2>/dev/null || true

echo "[2/3] Compressing profile data..."
tar -czf "$BACKUP_FILE" -C data/chromium-profile .

echo "[3/3] Resuming browser container..."
docker compose unpause browser 2>/dev/null || true

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo "=========================================="
echo "[SUCCESS] Backup completed!"
echo "File: $BACKUP_FILE"
echo "Size: $BACKUP_SIZE"
echo "=========================================="
