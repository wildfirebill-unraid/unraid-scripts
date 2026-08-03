#!/bin/bash
# extract_subtitles.sh - Extract embedded subtitles from media files
# Usage: ./extract_subtitles.sh --input /path --output /path [--lang eng] [--format srt|ass|vtt] [--all]

set -euo pipefail

INPUT=""
OUTPUT=""
LANG="eng"
FORMAT="srt"
EXTRACT_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --input) INPUT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --lang) LANG="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        --all) EXTRACT_ALL=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
    echo "Usage: $0 --input /path --output /path [options]"
    exit 1
fi

if [[ ! -f "$INPUT" ]]; then
    echo "Input file not found: $INPUT"
    exit 1
fi

mkdir -p "$OUTPUT"

BASENAME=$(basename "$INPUT" | sed 's/\.[^.]*$//')

echo "=== Extract Subtitles ==="
echo "Input: $INPUT"
echo "Output: $OUTPUT"
echo "Language: $LANG"
echo "Format: $FORMAT"

# Get subtitle tracks
SUBTITLES=$(ffprobe -v error -select_streams s -show_entries stream=index:stream_tags=language -of csv=p=0 "$INPUT" 2>/dev/null)

if [[ -z "$SUBTITLES" ]]; then
    echo "No subtitle tracks found"
    exit 0
fi

echo "Available subtitle tracks:"
echo "$SUBTITLES"

TRACK_COUNT=0

while IFS=',' read -r index language; do
    index=$(echo "$index" | xargs)
    language=$(echo "$language" | xargs)
    
    if [[ "$EXTRACT_ALL" == false && "$language" != "$LANG" ]]; then
        continue
    fi
    
    OUTPUT_FILE="$OUTPUT/${BASENAME}.${language}.${FORMAT}"
    
    echo "Extracting track $index ($language) -> $OUTPUT_FILE"
    
    ffmpeg -y -i "$INPUT" -map 0:"$index" -c:s "$FORMAT" "$OUTPUT_FILE"
    
    if [[ -f "$OUTPUT_FILE" && -s "$OUTPUT_FILE" ]]; then
        echo "  Success: $(wc -l < "$OUTPUT_FILE") lines"
        TRACK_COUNT=$((TRACK_COUNT + 1))
    else
        echo "  Failed or empty"
        rm -f "$OUTPUT_FILE"
    fi
done <<< "$SUBTITLES"

echo "Extracted $TRACK_COUNT subtitle track(s)"