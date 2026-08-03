#!/bin/bash
# backup-appdata.sh
# Backup Unraid appdata to a destination (local or remote)
# Usage: ./backup-appdata.sh [destination_path]

set -euo pipefail

# Configuration
APPDATA_SOURCE="/mnt/user/appdata"
LOG_FILE="/var/log/appdata-backup.log"
RETENTION_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

success() {
    log "${GREEN}$1${NC}"
}

warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Check source exists
if [[ ! -d "$APPDATA_SOURCE" ]]; then
    error "Appdata source not found: $APPDATA_SOURCE"
fi

DESTINATION="${1:-/mnt/user/backups/appdata}"

# Create destination if it doesn't exist
mkdir -p "$DESTINATION"

log "Starting appdata backup..."
log "Source: $APPDATA_SOURCE"
log "Destination: $DESTINATION"

# Create timestamped backup directory
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="$DESTINATION/appdata_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

# Perform backup with rsync
log "Syncing appdata..."
if rsync -avh --delete \
    --exclude="**/logs/*.log" \
    --exclude="**/cache/" \
    --exclude="**/tmp/" \
    --exclude="**/.git/" \
    "$APPDATA_SOURCE/" "$BACKUP_DIR/" 2>&1 | tee -a "$LOG_FILE"; then
    
    success "Backup completed: $BACKUP_DIR"
    
    # Calculate size
    SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    log "Backup size: $SIZE"
    
    # Create latest symlink
    ln -sfn "$BACKUP_DIR" "$DESTINATION/latest"
    
    # Cleanup old backups
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    find "$DESTINATION" -maxdepth 1 -type d -name "appdata_*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    
    success "Backup process completed successfully"
else
    error "Backup failed"
fi