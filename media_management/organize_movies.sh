#!/bin/bash
# organize_movies.sh - Organize movies into Movie (Year)/Movie (Year).ext structure
# Usage: ./organize_movies.sh --source /path --dest /path [--dry-run] [--link]

set -euo pipefail

SOURCE=""
DEST=""
DRY_RUN=true
USE_LINK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --source) SOURCE="$2"; shift 2 ;;
        --dest) DEST="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --execute) DRY_RUN=false; shift ;;
        --link) USE_LINK=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SOURCE" || -z "$DEST" ]]; then
    echo "Usage: $0 --source /path --dest /path [options]"
    exit 1
fi

if [[ ! -d "$SOURCE" ]]; then
    echo "Source not found: $SOURCE"
    exit 1
fi

mkdir -p "$DEST"

echo "=== Organize Movies ==="
echo "Source: $SOURCE"
echo "Dest: $DEST"
echo "Method: $([[ "$USE_LINK" == true ]] && echo "Hard link" || echo "Move")"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

ORGANIZED=0
SKIPPED=0

find "$SOURCE" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" -o -name "*.mov" \) | while read -r file; do
    FILENAME=$(basename "$file")
    
    # Try to extract movie name and year
    # Pattern: Movie.Name.2023.1080p.BluRay.x264-GROUP
    # Pattern: Movie Name (2023) [1080p]
    # Pattern: Movie.Name.(2023)
    
    MOVIE_NAME=""
    YEAR=""
    
    # Pattern with year in parentheses
    if [[ "$FILENAME" =~ ^(.+)[.\s]\(([0-9]{4})\) ]]; then
        MOVIE_NAME="${BASH_REMATCH[1]}"
        YEAR="${BASH_REMATCH[2]}"
    # Pattern with year at end before quality
    elif [[ "$FILENAME" =~ ^(.+)[.\s]([0-9]{4})[.\s](1080p|720p|2160p|4K|BluRay|BRRip|WEBRip|WEB-DL) ]]; then
        MOVIE_NAME="${BASH_REMATCH[1]}"
        YEAR="${BASH_REMATCH[2]}"
    # Pattern: Movie.Name.2023
    elif [[ "$FILENAME" =~ ^(.+)[.\s]([0-9]{4})[.\s] ]]; then
        MOVIE_NAME="${BASH_REMATCH[1]}"
        YEAR="${BASH_REMATCH[2]}"
    fi
    
    if [[ -n "$MOVIE_NAME" && -n "$YEAR" ]]; then
        # Clean movie name
        MOVIE_NAME=$(echo "$MOVIE_NAME" | sed 's/[._]/ /g' | sed 's/[^a-zA-Z0-9 ]//g' | xargs)
        
        FOLDER_NAME="${MOVIE_NAME} (${YEAR})"
        NEW_NAME="${FOLDER_NAME}.${FILENAME##*.}"
        
        DEST_DIR="$DEST/$FOLDER_NAME"
        DEST_FILE="$DEST_DIR/$NEW_NAME"
        
        mkdir -p "$DEST_DIR"
        
        if [[ -f "$DEST_FILE" ]]; then
            echo "SKIP (exists): $FILENAME -> $FOLDER_NAME/$NEW_NAME"
            SKIPPED=$((SKIPPED + 1))
        else
            echo "ORGANIZE: $FILENAME -> $FOLDER_NAME/$NEW_NAME"
            if [[ "$DRY_RUN" == false ]]; then
                if [[ "$USE_LINK" == true ]]; then
                    ln "$file" "$DEST_FILE"
                else
                    mv "$file" "$DEST_FILE"
                fi
            fi
            ORGANIZED=$((ORGANIZED + 1))
        fi
    else
        echo "SKIP (no match): $FILENAME"
        SKIPPED=$((SKIPPED + 1))
    fi
done

echo ""
echo "Organized: $ORGANIZED"
echo "Skipped: $SKIPPED"