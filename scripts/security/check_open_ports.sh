#!/bin/bash
# check_open_ports.sh - Scan for open ports and unexpected services
# Usage: ./check_open_ports.sh [--interface eth0] [--expected "22,80,443"] [--scan-local] [--scan-remote]

set -euo pipefail

INTERFACE=""
EXPECTED_PORTS="22,80,443"
SCAN_LOCAL=true
SCAN_REMOTE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --interface) INTERFACE="$2"; shift 2 ;;
        --expected) EXPECTED_PORTS="$2"; shift 2 ;;
        --scan-local) SCAN_LOCAL=true; shift ;;
        --scan-remote) SCAN_REMOTE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

IFS=',' read -ra EXPECTED <<< "$EXPECTED_PORTS"

echo "=== Open Ports Check ==="
echo "Expected ports: ${EXPECTED[*]}"

# Local scan using ss
echo ""
echo "--- Local Listening Ports (ss) ---"
ss -tuln | grep LISTEN | while read -r line; do
    PROTO=$(echo "$line" | awk '{print $1}')
    LOCAL=$(echo "$line" | awk '{print $5}')
    PORT=$(echo "$LOCAL" | sed 's/.*://')
    PROCESS=$(echo "$line" | awk '{print $7}' | cut -d= -f2)
    
    EXPECTED_MATCH=false
    for ep in "${EXPECTED[@]}"; do
        if [[ "$PORT" == "$ep" ]]; then
            EXPECTED_MATCH=true
            break
        fi
    done
    
    if [[ "$EXPECTED_MATCH" == true ]]; then
        echo "  OK: $PROTO $LOCAL ($PROCESS)"
    else
        echo "  UNEXPECTED: $PROTO $LOCAL ($PROCESS)"
    fi
done

# Remote scan using nmap if available
if [[ "$SCAN_REMOTE" == true ]] && command -v nmap &>/dev/null; then
    TARGET="${INTERFACE:-localhost}"
    echo ""
    echo "--- Remote Scan (nmap) ---"
    nmap -sS -p "${EXPECTED_PORTS//,/ }" "$TARGET" | grep -E "open|closed|filtered"
fi

# Check for common vulnerable ports
VULNERABLE_PORTS=("21" "23" "135" "139" "445" "1433" "3306" "3389" "5432" "5900" "6379" "8080" "27017")
echo ""
echo "--- Vulnerable Port Check ---"
for vp in "${VULNERABLE_PORTS[@]}"; do
    if ss -tuln | grep -q ":$vp "; then
        echo "  WARNING: Vulnerable port $vp is open"
    fi
done