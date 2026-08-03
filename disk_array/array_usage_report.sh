#!/bin/bash
# array_usage_report.sh - Generate detailed array usage report
# Usage: ./array_usage_report.sh [--format text|json|csv] [--output /path]

set -euo pipefail

FORMAT="text"
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --format) FORMAT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

REPORT_FILE="${OUTPUT:-/tmp/array_report_$(date +%Y%m%d_%H%M%S).$FORMAT}"

echo "=== Array Usage Report ===" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "Host: $(hostname)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Array info
if [[ -f /proc/mdstat ]]; then
    echo "## Array Status" >> "$REPORT_FILE"
    cat /proc/mdstat >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# Disk info
echo "## Disk Information" >> "$REPORT_FILE"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,SERIAL -J | jq -r '.blockdevices[] | select(.type=="disk") | "\(.name)\t\(.size)\t\(.model // "N/A")\t\(.serial // "N/A")\t\(.mountpoint // "N/A")"' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Filesystem usage
echo "## Filesystem Usage" >> "$REPORT_FILE"
df -hT | grep -E "^/dev/(md|sd)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Share usage (Unraid specific)
if [[ -d /mnt/user ]]; then
    echo "## User Share Usage" >> "$REPORT_FILE"
    for share in /mnt/user/*/; do
        if [[ -d "$share" ]]; then
            SHARE_NAME=$(basename "$share")
            SIZE=$(du -sh "$share" 2>/dev/null | cut -f1)
            echo "$SHARE_NAME: $SIZE" >> "$REPORT_FILE"
        fi
    done
    echo "" >> "$REPORT_FILE"
fi

# Cache pool info
if [[ -d /mnt/cache ]]; then
    echo "## Cache Pool" >> "$REPORT_FILE"
    df -h /mnt/cache >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# Convert format if needed
case $FORMAT in
    json)
        # Convert text to JSON (simplified)
        python3 -c "
import json, sys
with open('$REPORT_FILE') as f:
    lines = f.readlines()
report = {'generated': lines[1].strip(), 'host': lines[2].strip(), 'sections': {}}
current_section = None
for line in lines[4:]:
    line = line.strip()
    if line.startswith('## '):
        current_section = line[3:]
        report['sections'][current_section] = []
    elif line and current_section:
        report['sections'][current_section].append(line)
with open('$REPORT_FILE', 'w') as f:
    json.dump(report, f, indent=2)
"
        ;;
    csv)
        # Convert to CSV (simplified)
        python3 -c "
import csv, sys
with open('$REPORT_FILE') as f:
    lines = f.readlines()
with open('$REPORT_FILE', 'w') as f:
    writer = csv.writer(f)
    writer.writerow(['Section', 'Key', 'Value'])
    current_section = None
    for line in lines[4:]:
        line = line.strip()
        if line.startswith('## '):
            current_section = line[3:]
        elif ':' in line and current_section:
            key, val = line.split(':', 1)
            writer.writerow([current_section, key.strip(), val.strip()])
"
        ;;
esac

echo "Report saved to: $REPORT_FILE"
cat "$REPORT_FILE"