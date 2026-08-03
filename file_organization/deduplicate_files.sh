#!/bin/bash
# deduplicate_files.sh - Find and remove duplicate files
# Usage: ./deduplicate_files.sh --path /path [--algorithm sha256|md5] [--dry-run] [--delete] [--min-size N]

set -euo pipefail

PATH_TO_SCAN=""
ALGORITHM="sha256"
DRY_RUN=true
DELETE=false
MIN_SIZE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) PATH_TO_SCAN="$2"; shift 2 ;;
        --algorithm) ALGORITHM="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --delete) DELETE=true; DRY_RUN=false; shift ;;
        --min-size) MIN_SIZE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$PATH_TO_SCAN" ]]; then
    echo "Usage: $0 --path /path [options]"
    exit 1
fi

if [[ ! -d "$PATH_TO_SCAN" ]]; then
    echo "Path not found: $PATH_TO_SCAN"
    exit 1
fi

echo "=== Deduplicate Files ==="
echo "Path: $PATH_TO_SCAN"
echo "Algorithm: $ALGORITHM"
echo "Min size: $MIN_SIZE bytes"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE" || echo "DELETE MODE"

# Find files and compute hashes
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

echo "Scanning files..."
find "$PATH_TO_SCAN" -type f -size +"${MIN_SIZE}c" -print0 | while IFS= read -r -d '' file; do
    if [[ "$ALGORITHM" == "sha256" ]]; then
        HASH=$(sha256sum "$file" | awk '{print $1}')
    else
        HASH=$(md5sum "$file" | awk '{print $1}')
    fi
    SIZE=$(stat -c%s "$file")
    echo "$HASH|$SIZE|$file" >> "$TEMP_FILE"
done

# Find duplicates
echo "Finding duplicates..."
DUPLICATES=$(awk -F'|' '{print $1}' "$TEMP_FILE" | sort | uniq -d)

if [[ -z "$DUPLICATES" ]]; then
    echo "No duplicates found"
    exit 0
fi

TOTAL_SAVED=0
DUP_COUNT=0

for HASH in $DUPLICATES; do
    FILES=($(grep "^$HASH|" "$TEMP_FILE" | cut -d'|' -f3-))
    SIZE=$(grep "^$HASH|" "$TEMP_FILE" | head -1 | cut -d'|' -f2)
    
    if [[ ${#FILES[@]} -gt 1 ]]; then
        echo "Duplicate set (${#FILES[@]} files, $SIZE bytes each):"
        KEEP="${FILES[0]}"
        echo "  KEEP: $KEEP"
        
        for ((i=1; i<${#FILES[@]}; i++)); do
            DUP_FILE="${FILES[i]}"
            echo "  DUP:  $DUP_FILE"
            
            if [[ "$DRY_RUN" == true ]]; then
                echo "    [DRY RUN] Would delete"
            else
                rm "$DUP_FILE"
                echo "    DELETED"
            fi
            TOTAL_SAVED=$((TOTAL_SAVED + SIZE))
            DUP_COUNT=$((DUP_COUNT + 1))
        done
    fi
done

echo ""
echo "=== Summary ==="
echo "Duplicate sets found: $(echo "$DUPLICATES" | wc -w)"
echo "Files to remove: $DUP_COUNT"
echo "Space saved: $(numfmt --to=iec $TOTAL_SAVED)"