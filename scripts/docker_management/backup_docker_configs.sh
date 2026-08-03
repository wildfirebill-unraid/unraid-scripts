#!/bin/bash
# backup_docker_configs.sh - Backup Docker container configurations and volumes
# Usage: ./backup_docker_configs.sh [--dest /path/to/backup] [--include-volumes] [--compress]

set -euo pipefail

DEST="/mnt/user/backups/docker"
INCLUDE_VOLUMES=false
COMPRESS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --dest) DEST="$2"; shift 2 ;;
        --include-volumes) INCLUDE_VOLUMES=true; shift ;;
        --no-compress) COMPRESS=false; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$DEST/docker_backup_$DATE"

mkdir -p "$BACKUP_DIR"

echo "=== Docker Configuration Backup ==="
echo "Destination: $BACKUP_DIR"
echo "Include volumes: $INCLUDE_VOLUMES"
echo "Compress: $COMPRESS"

# Backup container labels and configs
echo "Backing up container configurations..."
docker ps -a --format "{{.Names}}" | while read -r container; do
    mkdir -p "$BACKUP_DIR/containers/$container"
    docker inspect "$container" > "$BACKUP_DIR/containers/$container/inspect.json"
    docker inspect --format '{{json .Config.Labels}}' "$container" > "$BACKUP_DIR/containers/$container/labels.json" 2>/dev/null || echo "{}" > "$BACKUP_DIR/containers/$container/labels.json"
done

# Backup docker-compose files if they exist
if [[ -d /mnt/user/appdata ]]; then
    echo "Backing up appdata..."
    cp -r /mnt/user/appdata "$BACKUP_DIR/" 2>/dev/null || true
fi

# Backup volumes if requested
if [[ "$INCLUDE_VOLUMES" == true ]]; then
    echo "Backing up Docker volumes..."
    mkdir -p "$BACKUP_DIR/volumes"
    docker volume ls -q | while read -r volume; do
        echo "  Backing up volume: $volume"
        docker run --rm -v "$volume":/source -v "$BACKUP_DIR/volumes":/backup alpine tar czf "/backup/$volume.tar.gz" -C /source . 2>/dev/null || true
    done
fi

# Create manifest
cat > "$BACKUP_DIR/manifest.txt" <<EOF
Backup Date: $(date)
Hostname: $(hostname)
Docker Version: $(docker version --format '{{.Server.Version}}')
Containers Backed Up: $(docker ps -a --format "{{.Names}}" | wc -l)
Include Volumes: $INCLUDE_VOLUMES
EOF

if [[ "$COMPRESS" == true ]]; then
    echo "Compressing backup..."
    tar czf "$BACKUP_DIR.tar.gz" -C "$DEST" "docker_backup_$DATE"
    rm -rf "$BACKUP_DIR"
    echo "Backup completed: $BACKUP_DIR.tar.gz"
else
    echo "Backup completed: $BACKUP_DIR"
fi

# Cleanup old backups (keep last 7)
find "$DEST" -name "docker_backup_*" -type f -mtime +7 -delete 2>/dev/null || true
find "$DEST" -name "docker_backup_*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true