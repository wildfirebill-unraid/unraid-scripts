#!/bin/bash
# check_disk_space.sh - Monitor disk space and alert if thresholds exceeded
# Usage: ./check_disk_space.sh [--warn-percent N] [--crit-percent N] [--exclude mount1,mount2]

set -euo pipefail

WARN_PERCENT=80
CRIT_PERCENT=90
EXCLUDE_MOUNTS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --warn-percent) WARN_PERCENT="$2"; shift 2 ;;
        --crit-percent) CRIT_PERCENT="$2"; shift 2 ;;
        --exclude) EXCLUDE_MOUNTS="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

EXCLUDE_ARRAY=()
IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_MOUNTS"

should_exclude() {
    local mount="$1"
    for excl in "${EXCLUDE_ARRAY[@]}"; do
        [[ "$mount" == *"$excl"* ]] && return 0
    done
    return 1
}

echo "=== Disk Space Check ==="
echo "Warning threshold: ${WARN_PERCENT}%"
echo "Critical threshold: ${CRIT_PERCENT}%"
echo ""

ALERTS=0

df -hP | tail -n +2 | while read -r line; do
    filesystem=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    used=$(echo "$line" | awk '{print $3}')
    avail=$(echo "$line" | awk '{print $4}')
    use_percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    mount=$(echo "$line" | awk '{print $6}')
    
    if should_exclude "$mount"; then
        continue
    fi
    
    if [[ $use_percent -ge $CRIT_PERCENT ]]; then
        echo "CRITICAL: $mount ($filesystem) - ${use_percent}% used ($used/$size)"
        ALERTS=$((ALERTS + 1))
    elif [[ $use_percent -ge $WARN_PERCENT ]]; then
        echo "WARNING: $mount ($filesystem) - ${use_percent}% used ($used/$size)"
        ALERTS=$((ALERTS + 1))
    else
        echo "OK: $mount ($filesystem) - ${use_percent}% used ($used/$size)"
    fi
done

echo ""
if [[ $ALERTS -gt 0 ]]; then
    echo "Total alerts: $ALERTS"
    exit 1
else
    echo "All disks within normal limits"
    exit 0
fi