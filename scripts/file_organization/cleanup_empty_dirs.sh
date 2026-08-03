#!/bin/bash
# cleanup_empty_dirs.sh - Remove empty directories recursively
# Usage: ./cleanup_empty_dirs.sh --path /path [--dry-run] [--min-depth N]

set -euo pipefail

PATH_TO_CLEAN=""
DRY_RUN=true
MIN_DEPTH=1

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) PATH_TO_CLEAN="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --delete) DRY_RUN=false; shift ;;
        --min-depth) MIN_DEPTH="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$PATH_TO_CLEAN" ]]; then
    echo "Usage: $0 --path /path [options]"
    exit 1
fi

if [[ ! -d "$PATH_TO_CLEAN" ]]; then
    echo "Path not found: $PATH_TO_CLEAN"
    exit 1
fi

echo "=== Cleanup Empty Directories ==="
echo "Path: $PATH_TO_CLEAN"
echo "Min depth: $MIN_DEPTH"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE" || echo "DELETE MODE"

# Find empty directories (depth >= MIN_DEPTH)
EMPTY_DIRS=$(find "$PATH_TO_CLEAN" -mindepth "$MIN_DEPTH" -type d -empty | sort -r)

if [[ -z "$EMPTY_DIRS" ]]; then
    echo "No empty directories found"
    exit 0
fi

COUNT=0
while IFS= read -r dir; do
    echo "Removing: $dir"
    if [[ "$DRY_RUN" == false ]]; then
        rmdir "$dir"
    fi
    COUNT=$((COUNT + 1))
done <<< "$EMPTY_DIRS"

echo "Removed $COUNT empty directories"