#!/bin/bash
# snapshot_btrfs.sh - Create Btrfs snapshots with retention
# Usage: ./snapshot_btrfs.sh --subvol /path --dest /path [--prefix name] [--keep N]

set -euo pipefail

SUBVOL=""
DEST=""
PREFIX="snapshot"
KEEP=30

while [[ $# -gt 0 ]]; do
    case $1 in
        --subvol) SUBVOL="$2"; shift 2 ;;
        --dest) DEST="$2"; shift 2 ;;
        --prefix) PREFIX="$2"; shift 2 ;;
        --keep) KEEP="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SUBVOL" || -z "$DEST" ]]; then
    echo "Usage: $0 --subvol /path --dest /path [options]"
    exit 1
fi

if ! btrfs subvolume show "$SUBVOL" &>/dev/null; then
    echo "Source is not a Btrfs subvolume: $SUBVOL"
    exit 1
fi

mkdir -p "$DEST"

DATE=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_NAME="${PREFIX}_${DATE}"
SNAPSHOT_PATH="$DEST/$SNAPSHOT_NAME"

echo "=== Btrfs Snapshot ==="
echo "Source: $SUBVOL"
echo "Destination: $SNAPSHOT_PATH"
echo "Keep: $KEEP snapshots"

# Create read-only snapshot
btrfs subvolume snapshot -r "$SUBVOL" "$SNAPSHOT_PATH"
echo "Snapshot created: $SNAPSHOT_NAME"

# Cleanup old snapshots
echo "Cleaning up old snapshots..."
SNAPSHOTS=($(find "$DEST" -maxdepth 1 -name "${PREFIX}_*" -type d | sort -r))
if [[ ${#SNAPSHOTS[@]} -gt $KEEP ]]; then
    for snapshot in "${SNAPSHOTS[@]:$KEEP}"; do
        echo "Deleting: $(basename "$snapshot")"
        btrfs subvolume delete "$snapshot"
    done
fi

REMAINING=($(find "$DEST" -maxdepth 1 -name "${PREFIX}_*" -type d | sort -r))
echo "Remaining snapshots: ${#REMAINING[@]}"