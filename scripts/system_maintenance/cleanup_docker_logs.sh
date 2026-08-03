#!/bin/bash
# cleanup_docker_logs.sh - Clean up Docker container logs older than specified days
# Usage: ./cleanup_docker_logs.sh [days_to_keep] [--dry-run]

set -euo pipefail

DAYS_TO_KEEP="${1:-7}"
DRY_RUN=false

if [[ "${2:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

LOG_DIR="/var/lib/docker/containers"
TOTAL_SIZE=0
CLEANED_SIZE=0

echo "=== Docker Log Cleanup ==="
echo "Keeping logs newer than $DAYS_TO_KEEP days"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE - No files will be deleted"
echo ""

if [[ ! -d "$LOG_DIR" ]]; then
    echo "Docker log directory not found: $LOG_DIR"
    exit 1
fi

while IFS= read -r -d '' log_file; do
    if [[ -f "$log_file" ]]; then
        file_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
        TOTAL_SIZE=$((TOTAL_SIZE + file_size))
        
        if [[ $(find "$log_file" -mtime +"$DAYS_TO_KEEP" -print 2>/dev/null) ]]; then
            CLEANED_SIZE=$((CLEANED_SIZE + file_size))
            if [[ "$DRY_RUN" == true ]]; then
                echo "[DRY RUN] Would delete: $log_file ($(numfmt --to=iec $file_size))"
            else
                echo "Deleting: $log_file ($(numfmt --to=iec $file_size))"
                : > "$log_file"
            fi
        fi
    fi
done < <(find "$LOG_DIR" -name "*.log" -type f -print0 2>/dev/null)

echo ""
echo "=== Summary ==="
echo "Total log size: $(numfmt --to=iec $TOTAL_SIZE)"
echo "Cleaned size: $(numfmt --to=iec $CLEANED_SIZE)"
echo "Remaining size: $(numfmt --to=iec $((TOTAL_SIZE - CLEANED_SIZE)))"