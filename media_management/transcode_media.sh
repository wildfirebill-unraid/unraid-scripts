#!/bin/bash
# transcode_media.sh - Transcode media files using ffmpeg
# Usage: ./transcode_media.sh --input /path --output /path [--codec h264|h265|vp9|av1] [--crf N] [--preset medium] [--dry-run]

set -euo pipefail

INPUT=""
OUTPUT=""
CODEC="h265"
CRF=23
PRESET="medium"
DRY_RUN=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --input) INPUT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --codec) CODEC="$2"; shift 2 ;;
        --crf) CRF="$2"; shift 2 ;;
        --preset) PRESET="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --execute) DRY_RUN=false; shift ;;
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

mkdir -p "$(dirname "$OUTPUT")"

# Codec options
case $CODEC in
    h264)
        VCODEC="libx264"
        EXTRA_OPTS="-profile:v high -level 4.1"
        ;;
    h265)
        VCODEC="libx265"
        EXTRA_OPTS="-x265-params log-level=error"
        ;;
    vp9)
        VCODEC="libvpx-vp9"
        EXTRA_OPTS="-b:v 0"
        ;;
    av1)
        VCODEC="libaom-av1"
        EXTRA_OPTS="-cpu-used 4 -tiles 2x2"
        ;;
    *)
        echo "Unknown codec: $CODEC"
        exit 1
        ;;
esac

echo "=== Media Transcode ==="
echo "Input: $INPUT"
echo "Output: $OUTPUT"
echo "Codec: $CODEC ($VCODEC)"
echo "CRF: $CRF"
echo "Preset: $PRESET"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

# Get input info
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT" 2>/dev/null)
SIZE=$(stat -c%s "$INPUT")

echo "Input size: $(numfmt --to=iec $SIZE)"
echo "Duration: ${DURATION}s"

FFMPEG_CMD=(
    ffmpeg -y -i "$INPUT"
    -c:v "$VCODEC" -crf "$CRF" -preset "$PRESET" $EXTRA_OPTS
    -c:a copy
    -movflags +faststart
    "$OUTPUT"
)

if [[ "$DRY_RUN" == true ]]; then
    echo "Would run: ${FFMPEG_CMD[*]}"
else
    echo "Starting transcode..."
    START_TIME=$(date +%s)
    "${FFMPEG_CMD[@]}"
    END_TIME=$(date +%s)
    
    ELAPSED=$((END_TIME - START_TIME))
    OUTPUT_SIZE=$(stat -c%s "$OUTPUT")
    
    echo "Transcode completed in ${ELAPSED}s"
    echo "Output size: $(numfmt --to=iec $OUTPUT_SIZE)"
    echo "Compression ratio: $(echo "scale=2; $SIZE / $OUTPUT_SIZE" | bc):1"
fi