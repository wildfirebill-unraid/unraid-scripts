#!/bin/bash
# network_monitor.sh - Monitor network connectivity and bandwidth
# Usage: ./network_monitor.sh [--interval N] [--target host] [--log-file /path] [--alert-webhook URL]

set -euo pipefail

INTERVAL=60
TARGET="8.8.8.8"
LOG_FILE="/var/log/network_monitor.log"
ALERT_WEBHOOK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --interval) INTERVAL="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        --log-file) LOG_FILE="$2"; shift 2 ;;
        --alert-webhook) ALERT_WEBHOOK="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

echo "=== Network Monitor ==="
echo "Target: $TARGET"
echo "Interval: ${INTERVAL}s"
echo "Log: $LOG_FILE"

FAILURE_COUNT=0
MAX_FAILURES=3

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ping test
    if ping -c 3 -W 2 "$TARGET" &>/dev/null; then
        PING_RESULT="OK"
        FAILURE_COUNT=0
    else
        PING_RESULT="FAIL"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
    
    # Get bandwidth stats
    INTERFACE=$(ip route get "$TARGET" | awk '{print $5; exit}')
    RX_BYTES=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_bytes 2>/dev/null || echo 0)
    TX_BYTES=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_bytes 2>/dev/null || echo 0)
    
    LOG_ENTRY="$TIMESTAMP,$TARGET,$PING_RESULT,$INTERFACE,$RX_BYTES,$TX_BYTES"
    echo "$LOG_ENTRY" >> "$LOG_FILE"
    
    if [[ "$PING_RESULT" == "FAIL" ]]; then
        echo "ALERT [$TIMESTAMP] Network unreachable: $TARGET (failure $FAILURE_COUNT/$MAX_FAILURES)" | tee -a "$LOG_FILE"
        
        if [[ $FAILURE_COUNT -ge $MAX_FAILURES && -n "$ALERT_WEBHOOK" ]]; then
            PAYLOAD=$(jq -n --arg text "Network unreachable: $TARGET" '{text: $text}')
            curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$ALERT_WEBHOOK" >/dev/null || true
        fi
    else
        echo "[$TIMESTAMP] Network OK: $TARGET via $INTERFACE"
    fi
    
    sleep "$INTERVAL"
done