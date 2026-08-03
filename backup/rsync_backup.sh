#!/bin/bash
# rsync_backup.sh - Rsync-based backup with rotation and verification
# Usage: ./rsync_backup.sh --source /path --dest /path [--exclude pattern] [--keep N] [--verify]

set -euo pipefail

SOURCE=""
DEST=""
EXCLUDE_PATTERNS=()
KEEP=7
VERIFY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --source) SOURCE="$2"; shift 2 ;;
        --dest) DEST="$2"; shift 2 ;;
        --exclude) EXCLUDE_PATTERNS+=("$2"); shift 2 ;;
        --keep) KEEP="$2"; shift 2 ;;
        --verify) VERIFY=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SOURCE" || -z "$DEST" ]]; then
    echo "Usage: $0 --source /path --dest /path [options]"
    exit 1
fi

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DEST="$DEST/backup_$DATE"
LATEST_LINK="$DEST/latest"

mkdir -p "$BACKUP_DEST"

EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    EXCLUDE_ARGS+=(--exclude="$pattern")
done

LINK_DEST_ARG=()
if [[ -L "$LATEST_LINK" && -d "$LATEST_LINK" ]]; then
    LINK_DEST_ARG=(--link-dest="$LATEST_LINK")
fi

echo "=== Rsync Backup ==="
echo "Source: $SOURCE"
echo "Destination: $BACKUP_DEST"
echo "Keep: $KEEP backups"
echo "Verify: $VERIFY"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

RSYNC_OPTS=(-avh --progress --delete "${EXCLUDE_ARGS[@]}" "${LINK_DEST_ARG[@]}" "$SOURCE/" "$BACKUP_DEST/")

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_OPTS+=(--dry-run)
fi

rsync "${RSYNC_OPTS[@]}"

if [[ "$DRY_RUN" == false ]]; then
    # Update latest symlink
    ln -sfn "$BACKUP_DEST" "$LATEST_LINK"
    
    # Verify backup
    if [[ "$VERIFY" == true ]]; then
        echo "Verifying backup..."
        rsync -avh --dry-run --checksum "${EXCLUDE_ARGS[@]}" "$SOURCE/" "$BACKUP_DEST/" | grep -E "^(send|recv)" || echo "Verification passed: No differences found"
    fi
    
    # Cleanup old backups
    echo "Cleaning up old backups (keeping $KEEP)..."
    find "$DEST" -maxdepth 1 -name "backup_*" -type d | sort -r | tail -n +$((KEEP + 1)) | xargs -r rm -rf
    
    echo "Backup completed: $BACKUP_DEST"
else
    echo "Dry run completed"
fi