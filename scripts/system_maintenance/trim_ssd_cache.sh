#!/bin/bash
# trim_ssd_cache.sh - Run fstrim on SSD cache pool to maintain performance
# Usage: ./trim_ssd_cache.sh [--verbose] [--pool pool_name]

set -euo pipefail

VERBOSE=false
POOL_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose) VERBOSE=true; shift ;;
        --pool) POOL_NAME="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== SSD Cache TRIM ==="

if [[ -n "$POOL_NAME" ]]; then
    MOUNT_POINT="/mnt/$POOL_NAME"
    if [[ ! -d "$MOUNT_POINT" ]]; then
        echo "Pool mount point not found: $MOUNT_POINT"
        exit 1
    fi
    echo "Trimming pool: $POOL_NAME ($MOUNT_POINT)"
    if [[ "$VERBOSE" == true ]]; then
        fstrim -v "$MOUNT_POINT"
    else
        fstrim "$MOUNT_POINT"
    fi
else
    echo "Trimming all mounted filesystems..."
    if [[ "$VERBOSE" == true ]]; then
        fstrim -av
    else
        fstrim -a
    fi
fi

echo "TRIM completed successfully"