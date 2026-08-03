#!/bin/bash
# organize_downloads.sh - Organize downloads folder by file type/date
# Usage: ./organize_downloads.sh --source /path --dest /path [--by-type] [--by-date] [--dry-run]

set -euo pipefail

SOURCE=""
DEST=""
BY_TYPE=true
BY_DATE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --source) SOURCE="$2"; shift 2 ;;
        --dest) DEST="$2"; shift 2 ;;
        --by-type) BY_TYPE=true; shift ;;
        --by-date) BY_DATE=true; BY_TYPE=false; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SOURCE" || -z "$DEST" ]]; then
    echo "Usage: $0 --source /path --dest /path [options]"
    exit 1
fi

declare -A TYPE_MAP=(
    ["jpg"]="Images" ["jpeg"]="Images" ["png"]="Images" ["gif"]="Images" ["webp"]="Images" ["bmp"]="Images" ["tiff"]="Images" ["svg"]="Images"
    ["mp4"]="Videos" ["mkv"]="Videos" ["avi"]="Videos" ["mov"]="Videos" ["wmv"]="Videos" ["flv"]="Videos" ["webm"]="Videos" ["m4v"]="Videos"
    ["mp3"]="Audio" ["flac"]="Audio" ["wav"]="Audio" ["ogg"]="Audio" ["m4a"]="Audio" ["aac"]="Audio"
    ["pdf"]="Documents" ["doc"]="Documents" ["docx"]="Documents" ["txt"]="Documents" ["rtf"]="Documents" ["odt"]="Documents" ["xls"]="Documents" ["xlsx"]="Documents" ["ppt"]="Documents" ["pptx"]="Documents"
    ["zip"]="Archives" ["rar"]="Archives" ["7z"]="Archives" ["tar"]="Archives" ["gz"]="Archives" ["bz2"]="Archives"
    ["exe"]="Software" ["msi"]="Software" ["dmg"]="Software" ["pkg"]="Software" ["apk"]="Software" ["deb"]="Software" ["rpm"]="Software"
    ["iso"]="Disk Images" ["img"]="Disk Images"
    ["torrent"]="Torrents"
)

echo "=== Organize Downloads ==="
echo "Source: $SOURCE"
echo "Dest: $DEST"
echo "By type: $BY_TYPE"
echo "By date: $BY_DATE"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

mkdir -p "$DEST"

find "$SOURCE" -maxdepth 1 -type f | while read -r file; do
    FILENAME=$(basename "$file")
    EXT="${FILENAME##*.}"
    EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$BY_DATE" == true ]]; then
        # Organize by modification date
        DATE_DIR=$(date -r "$file" +%Y/%m/%d)
        DEST_DIR="$DEST/$DATE_DIR"
    else
        # Organize by type
        CATEGORY="${TYPE_MAP[$EXT_LOWER]:-Other}"
        DEST_DIR="$DEST/$CATEGORY"
    fi
    
    mkdir -p "$DEST_DIR"
    
    # Handle duplicates
    DEST_FILE="$DEST_DIR/$FILENAME"
    if [[ -f "$DEST_FILE" ]]; then
        BASE="${FILENAME%.*}"
        EXT="${FILENAME##*.}"
        COUNTER=1
        while [[ -f "$DEST_DIR/${BASE}_${COUNTER}.${EXT}" ]]; do
            COUNTER=$((COUNTER + 1))
        done
        DEST_FILE="$DEST_DIR/${BASE}_${COUNTER}.${EXT}"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would move: $file -> $DEST_FILE"
    else
        mv "$file" "$DEST_FILE"
        echo "Moved: $FILENAME -> $DEST_DIR/"
    fi
done

echo "Organization completed"