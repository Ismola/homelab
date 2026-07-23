#!/bin/bash
set -euo pipefail

BACKUP_DIR="/mnt/nas/etcd-backups/opencloud/storage/users/users/934c2b07-76cc-49eb-8738-fc4ed171f4f3/4 Archives/Backup/etcd"
DATE="$(date +'%Y-%m-%d_%H-%M-%S')"
LOG_FILE="/var/log/k3s-etcd-backup.log"

mkdir -p "$BACKUP_DIR"

if ! mountpoint -q /mnt/nas/etcd-backups; then
  echo "$(date) ERROR: el NAS no está montado" >> "$LOG_FILE"
  exit 1
fi

k3s etcd-snapshot save \
  --name "etcd-${DATE}" \
  --dir "$BACKUP_DIR" >> "$LOG_FILE" 2>&1

find "$BACKUP_DIR" -type f \( -name "*.zip" -o -name "*.db" \) -mtime +14 -delete

echo "$(date) OK: backup etcd creado en $BACKUP_DIR" >> "$LOG_FILE"


