#!/bin/bash
# borg_backup.sh - BorgBackup with encryption and pruning
# Usage: ./borg_backup.sh --repo /path/to/repo --source /path [--password env_var] [--keep-daily N] [--keep-weekly N] [--keep-monthly N]

set -euo pipefail

REPO=""
SOURCE=""
PASSWORD_ENV="BORG_PASSPHRASE"
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6
COMPRESSION="lz4"
EXCLUDE_PATTERNS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo) REPO="$2"; shift 2 ;;
        --source) SOURCE="$2"; shift 2 ;;
        --password-env) PASSWORD_ENV="$2"; shift 2 ;;
        --keep-daily) KEEP_DAILY="$2"; shift 2 ;;
        --keep-weekly) KEEP_WEEKLY="$2"; shift 2 ;;
        --keep-monthly) KEEP_MONTHLY="$2"; shift 2 ;;
        --compression) COMPRESSION="$2"; shift 2 ;;
        --exclude) EXCLUDE_PATTERNS+=("$2"); shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$REPO" || -z "$SOURCE" ]]; then
    echo "Usage: $0 --repo /path --source /path [options]"
    exit 1
fi

if [[ -z "${!PASSWORD_ENV:-}" ]]; then
    echo "Password not found in environment variable: $PASSWORD_ENV"
    exit 1
fi

export BORG_PASSPHRASE="${!PASSWORD_ENV}"
export BORG_REPO="$REPO"

EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    EXCLUDE_ARGS+=(--exclude "$pattern")
done

echo "=== BorgBackup ==="
echo "Repository: $REPO"
echo "Source: $SOURCE"
echo "Compression: $COMPRESSION"
echo "Retention: daily=$KEEP_DAILY, weekly=$KEEP_WEEKLY, monthly=$KEEP_MONTHLY"

# Initialize repo if it doesn't exist
if ! borg list "$REPO" &>/dev/null; then
    echo "Initializing repository..."
    borg init --encryption=repokey "$REPO"
fi

# Create backup
ARCHIVE_NAME="{hostname}-{now:%Y-%m-%d_%H:%M:%S}"
borg create --stats --compression "$COMPRESSION" "${EXCLUDE_ARGS[@]}" "::$ARCHIVE_NAME" "$SOURCE"

# Prune old backups
echo "Pruning old backups..."
borg prune --list --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY"

# Compact repository
echo "Compacting repository..."
borg compact

echo "Backup completed successfully"