#!/bin/bash
# organize_tv_shows.sh - Organize TV shows into Show/Season/Episode structure
# Usage: ./organize_tv_shows.sh --source /path --dest /path [--dry-run] [--link]

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

echo "=== Organize TV Shows ==="
echo "Source: $SOURCE"
echo "Dest: $DEST"
echo "Method: $([[ "$USE_LINK" == true ]] && echo "Hard link" || echo "Move")"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

# Patterns for TV show detection
# Show.Name.S01E02.episode.title.ext
# Show.Name.1x02.episode.title.ext
# Show.Name - 1x02 - episode.title.ext

ORGANIZED=0
SKIPPED=0

find "$SOURCE" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" -o -name "*.mov" \) | while read -r file; do
    FILENAME=$(basename "$file")
    
    # Try to parse season/episode
    SHOW_NAME=""
    SEASON=""
    EPISODE=""
    EP_TITLE=""
    
    # Pattern 1: Show.Name.S01E02
    if [[ "$FILENAME" =~ ^(.+)[.\s][Ss]([0-9]+)[Ee]([0-9]+) ]]; then
        SHOW_NAME="${BASH_REMATCH[1]}"
        SEASON="${BASH_REMATCH[2]}"
        EPISODE="${BASH_REMATCH[3]}"
    # Pattern 2: Show.Name.1x02
    elif [[ "$FILENAME" =~ ^(.+)[.\s]([0-9]+)x([0-9]+) ]]; then
        SHOW_NAME="${BASH_REMATCH[1]}"
        SEASON="${BASH_REMATCH[2]}"
        EPISODE="${BASH_REMATCH[3]}"
    # Pattern 3: Show Name - 1x02 - Episode Title
    elif [[ "$FILENAME" =~ ^(.+)\s+-\s+([0-9]+)x([0-9]+)\s+-\s+(.+) ]]; then
        SHOW_NAME="${BASH_REMATCH[1]}"
        SEASON="${BASH_REMATCH[2]}"
        EPISODE="${BASH_REMATCH[3]}"
        EP_TITLE="${BASH_REMATCH[4]}"
    fi
    
    if [[ -n "$SHOW_NAME" && -n "$SEASON" && -n "$EPISODE" ]]; then
        # Clean show name
        SHOW_NAME=$(echo "$SHOW_NAME" | sed 's/[._]/ /g' | sed 's/[^a-zA-Z0-9 ]//g' | xargs)
        
        # Format season/episode
        SEASON_FMT=$(printf "Season %02d" "$SEASON")
        EPISODE_FMT=$(printf "S%02dE%02d" "$SEASON" "$EPISODE")
        
        if [[ -n "$EP_TITLE" ]]; then
            EP_TITLE=$(echo "$EP_TITLE" | sed 's/[._]/ /g' | sed 's/[^a-zA-Z0-9 ]//g' | xargs)
            NEW_NAME="${EPISODE_FMT} - ${EP_TITLE}.${FILENAME##*.}"
        else
            NEW_NAME="${EPISODE_FMT}.${FILENAME##*.}"
        fi
        
        DEST_DIR="$DEST/$SHOW_NAME/$SEASON_FMT"
        DEST_FILE="$DEST_DIR/$NEW_NAME"
        
        mkdir -p "$DEST_DIR"
        
        if [[ -f "$DEST_FILE" ]]; then
            echo "SKIP (exists): $FILENAME -> $SHOW_NAME/$SEASON_FMT/$NEW_NAME"
            SKIPPED=$((SKIPPED + 1))
        else
            echo "ORGANIZE: $FILENAME -> $SHOW_NAME/$SEASON_FMT/$NEW_NAME"
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