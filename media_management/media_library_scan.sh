#!/bin/bash
# media_library_scan.sh - Scan media library and generate report
# Usage: ./media_library_scan.sh --path /path [--type movies|tv|music] [--format json|csv|text] [--output file]

set -euo pipefail

PATH_TO_SCAN=""
TYPE="all"
FORMAT="text"
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) PATH_TO_SCAN="$2"; shift 2 ;;
        --type) TYPE="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
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

OUTPUT_FILE="${OUTPUT:-/tmp/media_scan_$(date +%Y%m%d_%H%M%S).$FORMAT}"

echo "=== Media Library Scan ==="
echo "Path: $PATH_TO_SCAN"
echo "Type: $TYPE"
echo "Output: $OUTPUT_FILE"

# Media extensions
declare -A MEDIA_TYPES=(
    ["movie"]="mkv mp4 avi mov m4v wmv flv webm"
    ["tv"]="mkv mp4 avi mov m4v"
    ["music"]="mp3 flac wav m4a ogg aac opus"
)

scan_directory() {
    local dir="$1"
    local media_type="$2"
    
    find "$dir" -type f | while read -r file; do
        EXT="${file##*.}"
        EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
        
        # Check if extension matches type
        MATCH=false
        if [[ "$media_type" == "all" ]]; then
            for exts in "${MEDIA_TYPES[@]}"; do
                if [[ " $exts " =~ " $EXT_LOWER " ]]; then
                    MATCH=true
                    break
                fi
            done
        else
            if [[ " ${MEDIA_TYPES[$media_type]} " =~ " $EXT_LOWER " ]]; then
                MATCH=true
            fi
        fi
        
        if [[ "$MATCH" == true ]]; then
            SIZE=$(stat -c%s "$file")
            MTIME=$(stat -c%Y "$file")
            
            # Get media info if tools available
            DURATION=""
            RESOLUTION=""
            BITRATE=""
            
            if command -v mediainfo &>/dev/null; then
                DURATION=$(mediainfo --Inform="General;%Duration%" "$file" 2>/dev/null | head -1)
                RESOLUTION=$(mediainfo --Inform="Video;%Width%x%Height%" "$file" 2>/dev/null | head -1)
                BITRATE=$(mediainfo --Inform="General;%OverallBitRate%" "$file" 2>/dev/null | head -1)
            fi
            
            case $FORMAT in
                json)
                    echo "{\"path\":\"$file\",\"size\":$SIZE,\"mtime\":$MTIME,\"ext\":\"$EXT_LOWER\",\"duration\":\"$DURATION\",\"resolution\":\"$RESOLUTION\",\"bitrate\":\"$BITRATE\"}"
                    ;;
                csv)
                    echo "\"$file\",$SIZE,$MTIME,$EXT_LOWER,\"$DURATION\",\"$RESOLUTION\",\"$BITRATE\""
                    ;;
                *)
                    echo "File: $file"
                    echo "  Size: $(numfmt --to=iec $SIZE)"
                    echo "  Modified: $(date -d @$MTIME)"
                    [[ -n "$DURATION" ]] && echo "  Duration: ${DURATION}ms"
                    [[ -n "$RESOLUTION" ]] && echo "  Resolution: $RESOLUTION"
                    [[ -n "$BITRATE" ]] && echo "  Bitrate: $BITRATE"
                    echo ""
                    ;;
            esac
        fi
    done
}

{
    if [[ "$FORMAT" == "csv" ]]; then
        echo "path,size,mtime,ext,duration,resolution,bitrate"
    elif [[ "$FORMAT" == "json" ]]; then
        echo "["
        FIRST=true
    fi
    
    scan_directory "$PATH_TO_SCAN" "$TYPE"
    
    if [[ "$FORMAT" == "json" ]]; then
        echo "]"
    fi
} > "$OUTPUT_FILE"

# Fix JSON formatting (remove trailing comma)
if [[ "$FORMAT" == "json" ]]; then
    sed -i '$s/,$//' "$OUTPUT_FILE"
fi

echo "Scan completed: $OUTPUT_FILE"