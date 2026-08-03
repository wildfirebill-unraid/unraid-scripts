#!/bin/bash
# system_info.sh - Collect comprehensive system information
# Usage: ./system_info.sh [--format text|json] [--output file]

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

OUTPUT_FILE="${OUTPUT:-/tmp/system_info_$(date +%Y%m%d_%H%M%S).txt}"

collect_info() {
    echo "=== System Information ==="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "--- OS ---"
    cat /etc/os-release 2>/dev/null | grep -E "^(NAME|VERSION|ID)=" | sed 's/^/  /'
    echo "  Kernel: $(uname -r)"
    echo "  Uptime: $(uptime -p)"
    echo ""
    
    echo "--- Hardware ---"
    echo "  CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo "  Cores: $(nproc)"
    echo "  Memory: $(free -h | awk 'NR==2{print $2}')"
    echo "  Architecture: $(uname -m)"
    echo ""
    
    echo "--- Disks ---"
    lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,MOUNTPOINT -d | grep -v loop | sed 's/^/  /'
    echo ""
    
    echo "--- Filesystems ---"
    df -hT | grep -E "^/dev/(md|sd|nvme)" | sed 's/^/  /'
    echo ""
    
    echo "--- Network ---"
    ip -br addr | sed 's/^/  /'
    echo ""
    
    echo "--- Docker ---"
    if command -v docker &>/dev/null; then
        echo "  Version: $(docker version --format '{{.Server.Version}}')"
        echo "  Containers: $(docker ps -q | wc -l) running, $(docker ps -aq | wc -l) total"
        echo "  Images: $(docker images -q | wc -l)"
    else
        echo "  Not installed"
    fi
    echo ""
    
    echo "--- Load ---"
    uptime | sed 's/^/  /'
    echo ""
    
    echo "--- Memory ---"
    free -h | sed 's/^/  /'
    echo ""
}

if [[ "$FORMAT" == "json" ]]; {
    collect_info | python3 -c "
import sys, json, re
lines = sys.stdin.read().strip().split('\n')
result = {}
current_section = None
for line in lines:
    if line.startswith('--- ') and line.endswith(' ---'):
        current_section = line[4:-4].lower().replace(' ', '_')
        result[current_section] = {}
    elif current_section and ': ' in line:
        key, val = line.split(': ', 1)
        result[current_section][key.strip()] = val.strip()
print(json.dumps(result, indent=2))
" > "$OUTPUT_FILE"
} else {
    collect_info > "$OUTPUT_FILE"
}

cat "$OUTPUT_FILE"
echo "Report saved to: $OUTPUT_FILE"