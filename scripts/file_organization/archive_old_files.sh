#!/bin/bash
# archive_old_files.sh - Archive files older than X days to cold storage
# Usage: ./archive_old_files.sh --source /path --dest /path --days N [--compress] [--dry-run]

set -euo pipefail

SOURCE=""
DEST=""
DAYS=365
COMPRESS=true
DRY_RUN=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --source) SOURCE="$2"; shift 2 ;;
        --dest) DEST="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        --compress) COMPRESS=true; shift ;;
        --no-compress) COMPRESS=false; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --execute) DRY_RUN=false; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SOURCE" || -z "$DEST" ]]; then
    echo "Usage: $0 --source /path --dest /path --days N [options]"
    exit 1
fi

if [[ ! -d "$SOURCE" ]]; then
    echo "Source not found: $SOURCE"
    exit 1
fi

mkdir -p "$DEST"

echo "=== Archive Old Files ==="
echo "Source: $SOURCE"
echo "Dest: $DEST"
echo "Days: $DAYS"
echo "Compress: $COMPRESS"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE" || echo "EXECUTE MODE"

DATE=$(date +%Y%m%d)
ARCHIVE_NAME="archive_${DATE}"

if [[ "$COMPRESS" == true ]]; then
    ARCHIVE_FILE="$DEST/${ARCHIVE_NAME}.tar.gz"
else
    ARCHIVE_FILE="$DEST/${ARCHIVE_NAME}"
fi

# Find old files
OLD_FILES=$(find "$SOURCE" -type f -mtime +"$DAYS" ! -path "*/.*" 2>/dev/null)

if [[ -z "$OLD_FILES" ]]; then
    echo "No files older than $DAYS days found"
    exit 0
fi

FILE_COUNT=$(echo "$OLD_FILES" | wc -l)
TOTAL_SIZE=$(echo "$OLD_FILES" | xargs stat -c%s 2>/dev/null | awk '{sum+=$1} END {print sum}')

echo "Files to archive: $FILE_COUNT"
echo "Total size: $(numfmt --to=iec $TOTAL_SIZE)"

if [[ "$DRY_RUN" == true ]]; then
    echo "Files that would be archived:"
    echo "$OLD_FILES" | head -20
    [[ $FILE_COUNT -gt 20 ]] && echo "... and $((FILE_COUNT - 20)) more"
else
    if [[ "$COMPRESS" == true ]]; then
        echo "Creating compressed archive..."
        tar czf "$ARCHIVE_FILE" -C "$SOURCE" $(echo "$OLD_FILES" | sed "s|$SOURCE/||")
    else
        echo "Creating archive..."
        mkdir -p "$ARCHIVE_FILE"
        echo "$OLD_FILES" | while read -r file; do
            REL_PATH="${file#$SOURCE/}"
            DEST_DIR="$ARCHIVE_FILE/$(dirname "$REL_PATH")"
            mkdir -p "$DEST_DIR"
            mv "$file" "$DEST_DIR/"
        done
    fi
    
    # Verify archive
    if [[ "$COMPRESS" == true ]]; then
        ARCHIVE_COUNT=$(tar tzf "$ARCHIVE_FILE" | wc -l)
    else
        ARCHIVE_COUNT=$(find "$ARCHIVE_FILE" -type f | wc -l)
    fi
    
    if [[ $ARCHIVE_COUNT -eq $FILE_COUNT ]]; then
        echo "Archive verified: $ARCHIVE_COUNT files"
        echo "Archive: $ARCHIVE_FILE"
    else
        echo "WARNING: Archive count mismatch! Expected $FILE_COUNT, got $ARCHIVE_COUNT"
    fi
fi