#!/bin/bash
# verify_backup_integrity.sh - Verify backup integrity using checksums
# Usage: ./verify_backup_integrity.sh --backup /path/to/backup [--checksum-file /path] [--algorithm sha256|md5]

set -euo pipefail

BACKUP_PATH=""
CHECKSUM_FILE=""
ALGORITHM="sha256"

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup) BACKUP_PATH="$2"; shift 2 ;;
        --checksum-file) CHECKSUM_FILE="$2"; shift 2 ;;
        --algorithm) ALGORITHM="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$BACKUP_PATH" ]]; then
    echo "Usage: $0 --backup /path [options]"
    exit 1
fi

if [[ ! -e "$BACKUP_PATH" ]]; then
    echo "Backup not found: $BACKUP_PATH"
    exit 1
fi

echo "=== Backup Integrity Verification ==="
echo "Backup: $BACKUP_PATH"
echo "Algorithm: $ALGORITHM"

if [[ -f "$BACKUP_PATH" ]]; then
    # Single file backup
    if [[ -n "$CHECKSUM_FILE" && -f "$CHECKSUM_FILE" ]]; then
        echo "Verifying against checksum file..."
        if [[ "$ALGORITHM" == "sha256" ]]; then
            sha256sum -c "$CHECKSUM_FILE"
        else
            md5sum -c "$CHECKSUM_FILE"
        fi
    else
        echo "Generating checksum..."
        if [[ "$ALGORITHM" == "sha256" ]]; then
            sha256sum "$BACKUP_PATH" | tee "${BACKUP_PATH}.sha256"
        else
            md5sum "$BACKUP_PATH" | tee "${BACKUP_PATH}.md5"
        fi
    fi
else
    # Directory backup
    CHECKSUM_FILE="${CHECKSUM_FILE:-${BACKUP_PATH}.${ALGORITHM}}"
    
    if [[ -f "$CHECKSUM_FILE" ]]; then
        echo "Verifying directory against checksum file..."
        cd "$BACKUP_PATH"
        if [[ "$ALGORITHM" == "sha256" ]]; then
            sha256sum -c "$CHECKSUM_FILE"
        else
            md5sum -c "$CHECKSUM_FILE"
        fi
    else
        echo "Generating checksums for directory..."
        cd "$BACKUP_PATH"
        if [[ "$ALGORITHM" == "sha256" ]]; then
            find . -type f -exec sha256sum {} + | sort > "$CHECKSUM_FILE"
        else
            find . -type f -exec md5sum {} + | sort > "$CHECKSUM_FILE"
        fi
        echo "Checksums saved to: $CHECKSUM_FILE"
    fi
fi

echo "Verification completed"