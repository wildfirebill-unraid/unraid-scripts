#!/bin/bash
# balance_btrfs.sh - Balance Btrfs filesystem to reclaim space
# Usage: ./balance_btrfs.sh --mount /path [--usage N] [--musage N] [--dry-run]

set -euo pipefail

MOUNT=""
USAGE=0
MUSAGE=0
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --mount) MOUNT="$2"; shift 2 ;;
        --usage) USAGE="$2"; shift 2 ;;
        --musage) MUSAGE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$MOUNT" ]]; then
    echo "Usage: $0 --mount /path [options]"
    exit 1
fi

if ! findmnt "$MOUNT" | grep -q btrfs; then
    echo "Mount point is not Btrfs: $MOUNT"
    exit 1
fi

echo "=== Btrfs Balance ==="
echo "Mount: $MOUNT"
echo "Data usage filter: $USAGE%"
echo "Metadata usage filter: $MUSAGE%"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

# Show current usage
echo "Current usage:"
btrfs filesystem usage "$MOUNT"

BALANCE_OPTS=()
if [[ $USAGE -gt 0 ]]; then
    BALANCE_OPTS+=(-dusage=$USAGE)
fi
if [[ $MUSAGE -gt 0 ]]; then
    BALANCE_OPTS+=(-musage=$MUSAGE)
fi

if [[ ${#BALANCE_OPTS[@]} -eq 0 ]]; then
    BALANCE_OPTS+=(-dusage=0 -musage=0)
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Would run: btrfs balance start ${BALANCE_OPTS[@]} $MOUNT"
    btrfs balance start --dry-run "${BALANCE_OPTS[@]}" "$MOUNT"
else
    echo "Starting balance..."
    btrfs balance start "${BALANCE_OPTS[@]}" "$MOUNT"
    echo "Balance completed"
    echo "New usage:"
    btrfs filesystem usage "$MOUNT"
fi