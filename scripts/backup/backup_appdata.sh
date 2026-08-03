#!/bin/bash
# backup_appdata.sh - Backup Unraid appdata with container stop/start
# Usage: ./backup_appdata.sh [--dest /path] [--stop-containers] [--containers name1,name2] [--compress] [--keep N]

set -euo pipefail

DEST="/mnt/user/backups/appdata"
STOP_CONTAINERS=false
CONTAINERS=""
COMPRESS=true
KEEP=7

while [[ $# -gt 0 ]]; do
    case $1 in
        --dest) DEST="$2"; shift 2 ;;
        --stop-containers) STOP_CONTAINERS=true; shift ;;
        --containers) CONTAINERS="$2"; shift 2 ;;
        --no-compress) COMPRESS=false; shift ;;
        --keep) KEEP="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

APPDATA_SOURCE="/mnt/user/appdata"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$DEST/appdata_$DATE"

mkdir -p "$BACKUP_DIR"

echo "=== Appdata Backup ==="
echo "Source: $APPDATA_SOURCE"
echo "Destination: $BACKUP_DIR"
echo "Stop containers: $STOP_CONTAINERS"
echo "Compress: $COMPRESS"

# Determine containers to stop
CONTAINER_ARRAY=()
if [[ -n "$CONTAINERS" ]]; then
    IFS=',' read -ra CONTAINER_ARRAY <<< "$CONTAINERS"
else
    # Get all containers with appdata mounts
    mapfile -t CONTAINER_ARRAY < <(docker ps --format "{{.Names}}" | while read -r c; do
        docker inspect "$c" --format '{{range .Mounts}}{{if eq .Destination "/config"}}{{.Name}}{{end}}{{end}}' | grep -q . && echo "$c"
    done)
fi

# Stop containers if requested
if [[ "$STOP_CONTAINERS" == true && ${#CONTAINER_ARRAY[@]} -gt 0 ]]; then
    echo "Stopping containers: ${CONTAINER_ARRAY[*]}"
    for container in "${CONTAINER_ARRAY[@]}"; do
        docker stop "$container" --time 60
    done
    sleep 5
fi

# Perform backup
echo "Backing up appdata..."
if [[ "$COMPRESS" == true ]]; then
    tar czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$APPDATA_SOURCE")" "$(basename "$APPDATA_SOURCE")"
    BACKUP_PATH="$BACKUP_DIR.tar.gz"
else
    rsync -avh --delete "$APPDATA_SOURCE/" "$BACKUP_DIR/"
    BACKUP_PATH="$BACKUP_DIR"
fi

# Restart containers
if [[ "$STOP_CONTAINERS" == true && ${#CONTAINER_ARRAY[@]} -gt 0 ]]; then
    echo "Starting containers: ${CONTAINER_ARRAY[*]}"
    for container in "${CONTAINER_ARRAY[@]}"; do
        docker start "$container"
    done
fi

# Cleanup old backups
echo "Cleaning up old backups (keeping $KEEP)..."
find "$DEST" -maxdepth 1 \( -name "appdata_*.tar.gz" -o -name "appdata_*" -type d \) | sort -r | tail -n +$((KEEP + 1)) | xargs -r rm -rf

echo "Appdata backup completed: $BACKUP_PATH"