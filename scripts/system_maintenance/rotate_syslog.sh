#!/bin/bash
# rotate_syslog.sh - Rotate and compress system logs
# Usage: ./rotate_syslog.sh [--keep-days N] [--compress]

set -euo pipefail

KEEP_DAYS=30
COMPRESS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-days) KEEP_DAYS="$2"; shift 2 ;;
        --no-compress) COMPRESS=false; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

LOG_DIR="/var/log"
echo "=== Syslog Rotation ==="
echo "Keeping logs for $KEEP_DAYS days"
echo "Compression: $COMPRESS"

find "$LOG_DIR" -name "*.log" -type f -mtime +"$KEEP_DAYS" | while read -r log_file; do
    if [[ "$COMPRESS" == true && "$log_file" != *.gz ]]; then
        echo "Compressing: $log_file"
        gzip "$log_file"
    else
        echo "Removing: $log_file"
        rm -f "$log_file"
    fi
done

find "$LOG_DIR" -name "*.gz" -type f -mtime +"$KEEP_DAYS" -delete

echo "Syslog rotation completed"