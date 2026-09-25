#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

BACKUP_DIR="${PROJECT_ROOT}/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/browser-profiles-${TIMESTAMP}.tar.gz"

echo "=========================================="
echo "   Browser Profiles Backup Utility"
echo "=========================================="
echo "Backup destination: ${BACKUP_FILE}"

echo "[1/3] Pausing containers for consistent disk snapshot..."
docker compose pause browser-desktop browser-mobile 2>/dev/null || true

echo "[2/3] Compressing desktop and mobile profiles..."
tar -czf "$BACKUP_FILE" -C data .

echo "[3/3] Resuming browser containers..."
docker compose unpause browser-desktop browser-mobile 2>/dev/null || true

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo "=========================================="
echo "[SUCCESS] Backup completed!"
echo "File: $BACKUP_FILE"
echo "Size: $BACKUP_SIZE"
echo "=========================================="
