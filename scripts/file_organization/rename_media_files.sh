#!/bin/bash
# rename_media_files.sh - Rename media files using metadata (EXIF, ID3, etc.)
# Usage: ./rename_media_files.sh --path /path [--pattern "pattern"] [--dry-run] [--recursive]

set -euo pipefail

PATH_TO_RENAME=""
PATTERN="{date}_{title}"
DRY_RUN=true
RECURSIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) PATH_TO_RENAME="$2"; shift 2 ;;
        --pattern) PATTERN="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --execute) DRY_RUN=false; shift ;;
        --recursive) RECURSIVE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$PATH_TO_RENAME" ]]; then
    echo "Usage: $0 --path /path [options]"
    exit 1
fi

if [[ ! -d "$PATH_TO_RENAME" ]]; then
    echo "Path not found: $PATH_TO_RENAME"
    exit 1
fi

FIND_OPTS=(-type f)
if [[ "$RECURSIVE" == false ]]; then
    FIND_OPTS+=(-maxdepth 1)
fi

# Supported extensions
EXTENSIONS=("jpg" "jpeg" "png" "mp4" "mkv" "mov" "mp3" "flac" "m4a")

echo "=== Rename Media Files ==="
echo "Path: $PATH_TO_RENAME"
echo "Pattern: $PATTERN"
echo "Recursive: $RECURSIVE"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE" || echo "EXECUTE MODE"

RENAMED=0

find "$PATH_TO_RENAME" "${FIND_OPTS[@]}" | while read -r file; do
    EXT="${file##*.}"
    EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
    
    # Check if supported
    SUPPORTED=false
    for e in "${EXTENSIONS[@]}"; do
        if [[ "$EXT_LOWER" == "$e" ]]; then
            SUPPORTED=true
            break
        fi
    done
    
    [[ "$SUPPORTED" == false ]] && continue
    
    # Extract metadata based on file type
    DATE=""
    TITLE=""
    
    if [[ "$EXT_LOWER" =~ ^(jpg|jpeg|png)$ ]]; then
        # Image - use EXIF
        DATE=$(exiftool -DateTimeOriginal -s3 "$file" 2>/dev/null | head -1 | sed 's/[: ]/-/g' | cut -c1-10)
        TITLE=$(exiftool -Title -s3 "$file" 2>/dev/null | head -1)
    elif [[ "$EXT_LOWER" =~ ^(mp4|mkv|mov)$ ]]; then
        # Video - use creation time
        DATE=$(mediainfo --Inform="General;%Encoded_Date%" "$file" 2>/dev/null | head -1 | cut -c1-10 | sed 's/[-:]/-/g')
        TITLE=$(mediainfo --Inform="General;%Title%" "$file" 2>/dev/null | head -1)
    elif [[ "$EXT_LOWER" =~ ^(mp3|flac|m4a)$ ]]; then
        # Audio - use ID3 tags
        DATE=$(exiftool -CreateDate -s3 "$file" 2>/dev/null | head -1 | sed 's/[: ]/-/g' | cut -c1-10)
        TITLE=$(exiftool -Title -s3 "$file" 2>/dev/null | head -1)
    fi
    
    # Fallback to file modification time
    if [[ -z "$DATE" ]]; then
        DATE=$(date -r "$file" +%Y-%m-%d)
    fi
    
    # Fallback to filename
    if [[ -z "$TITLE" ]]; then
        TITLE=$(basename "$file" ."$EXT_LOWER")
        # Clean up title
        TITLE=$(echo "$TITLE" | sed 's/[_.-]/ /g' | sed 's/[^a-zA-Z0-9 ]//g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1' | sed 's/ /_/g')
    fi
    
    # Build new filename
    NEW_NAME=$(echo "$PATTERN" | sed "s/{date}/$DATE/g" | sed "s/{title}/$TITLE/g")
    NEW_FILE="$(dirname "$file")/${NEW_NAME}.${EXT_LOWER}"
    
    # Handle conflicts
    if [[ "$file" != "$NEW_FILE" ]]; then
        COUNTER=1
        ORIGINAL_NEW="$NEW_FILE"
        while [[ -f "$NEW_FILE" ]]; do
            NEW_FILE="$(dirname "$file")/${NEW_NAME}_${COUNTER}.${EXT_LOWER}"
            COUNTER=$((COUNTER + 1))
        done
        
        echo "Renaming: $(basename "$file") -> $(basename "$NEW_FILE")"
        if [[ "$DRY_RUN" == false ]]; then
            mv "$file" "$NEW_FILE"
        fi
        RENAMED=$((RENAMED + 1))
    fi
done

echo "Renamed $RENAMED files"