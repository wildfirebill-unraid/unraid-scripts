#!/bin/bash
# file_integrity_monitor.sh - Monitor file integrity using AIDE or manual hashing
# Usage: ./file_integrity_monitor.sh --path /path [--init] [--check] [--update] [--algorithm sha256|md5]

set -euo pipefail

PATH_TO_MONITOR=""
ACTION="check"
ALGORITHM="sha256"
DB_FILE="/var/lib/file_integrity.db"

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) PATH_TO_MONITOR="$2"; shift 2 ;;
        --init) ACTION="init"; shift ;;
        --check) ACTION="check"; shift ;;
        --update) ACTION="update"; shift ;;
        --algorithm) ALGORITHM="$2"; shift 2 ;;
        --db) DB_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$PATH_TO_MONITOR" ]]; then
    echo "Usage: $0 --path /path --init|--check|--update [options]"
    exit 1
fi

mkdir -p "$(dirname "$DB_FILE")"

compute_hash() {
    local file="$1"
    if [[ "$ALGORITHM" == "sha256" ]]; then
        sha256sum "$file" | awk '{print $1}'
    else
        md5sum "$file" | awk '{print $1}'
    fi
}

case $ACTION in
    init)
        echo "=== Initializing File Integrity Database ==="
        echo "Path: $PATH_TO_MONITOR"
        echo "Database: $DB_FILE"
        
        > "$DB_FILE"
        find "$PATH_TO_MONITOR" -type f | while read -r file; do
            HASH=$(compute_hash "$file")
            SIZE=$(stat -c%s "$file")
            MTIME=$(stat -c%Y "$file")
            echo "$file|$HASH|$SIZE|$MTIME" >> "$DB_FILE"
        done
        
        COUNT=$(wc -l < "$DB_FILE")
        echo "Database initialized with $COUNT files"
        ;;
        
    check)
        echo "=== Checking File Integrity ==="
        echo "Path: $PATH_TO_MONITOR"
        echo "Database: $DB_FILE"
        
        if [[ ! -f "$DB_FILE" ]]; then
            echo "Database not found. Run --init first."
            exit 1
        fi
        
        CHANGED=0
        MISSING=0
        NEW=0
        
        # Check existing files
        while IFS='|' read -r file hash size mtime; do
            if [[ ! -f "$file" ]]; then
                echo "MISSING: $file"
                MISSING=$((MISSING + 1))
                continue
            fi
            
            CURRENT_HASH=$(compute_hash "$file")
            CURRENT_SIZE=$(stat -c%s "$file")
            CURRENT_MTIME=$(stat -c%Y "$file")
            
            if [[ "$CURRENT_HASH" != "$hash" ]]; then
                echo "CHANGED: $file (hash mismatch)"
                CHANGED=$((CHANGED + 1))
            elif [[ "$CURRENT_SIZE" != "$size" ]]; then
                echo "CHANGED: $file (size mismatch)"
                CHANGED=$((CHANGED + 1))
            elif [[ "$CURRENT_MTIME" != "$mtime" ]]; then
                echo "CHANGED: $file (mtime mismatch)"
                CHANGED=$((CHANGED + 1))
            fi
        done < "$DB_FILE"
        
        # Check for new files
        while IFS= read -r file; do
            if ! grep -q "^$file|" "$DB_FILE"; then
                echo "NEW: $file"
                NEW=$((NEW + 1))
            fi
        done < <(find "$PATH_TO_MONITOR" -type f)
        
        echo ""
        echo "=== Summary ==="
        echo "Changed: $CHANGED"
        echo "Missing: $MISSING"
        echo "New: $NEW"
        
        [[ $CHANGED -gt 0 || $MISSING -gt 0 || $NEW -gt 0 ]] && exit 1 || exit 0
        ;;
        
    update)
        echo "=== Updating File Integrity Database ==="
        # Re-initialize
        $0 --path "$PATH_TO_MONITOR" --init --algorithm "$ALGORITHM" --db "$DB_FILE"
        ;;
esac