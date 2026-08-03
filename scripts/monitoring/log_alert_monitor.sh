#!/bin/bash
# log_alert_monitor.sh - Monitor logs for patterns and alert
# Usage: ./log_alert_monitor.sh --log /path/to/log --pattern "regex" [--interval N] [--webhook URL] [--cooldown N]

set -euo pipefail

LOG_FILE=""
PATTERN=""
INTERVAL=60
WEBHOOK=""
COOLDOWN=300

while [[ $# -gt 0 ]]; do
    case $1 in
        --log) LOG_FILE="$2"; shift 2 ;;
        --pattern) PATTERN="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --webhook) WEBHOOK="$2"; shift 2 ;;
        --cooldown) COOLDOWN="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$LOG_FILE" || -z "$PATTERN" ]]; then
    echo "Usage: $0 --log /path --pattern \"regex\" [options]"
    exit 1
fi

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Log file not found: $LOG_FILE"
    exit 1
fi

COOLDOWN_FILE="/tmp/log_monitor_cooldown_$(echo "$LOG_FILE$PATTERN" | md5sum | cut -d' ' -f1)"
LAST_ALERT=0

if [[ -f "$COOLDOWN_FILE" ]]; then
    LAST_ALERT=$(cat "$COOLDOWN_FILE")
fi

echo "=== Log Alert Monitor ==="
echo "Log: $LOG_FILE"
echo "Pattern: $PATTERN"
echo "Interval: ${INTERVAL}s"
echo "Cooldown: ${COOLDOWN}s"

LAST_POS=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)

while true; do
    CURRENT_POS=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    
    if [[ $CURRENT_POS -lt $LAST_POS ]]; then
        # Log rotated
        LAST_POS=0
    fi
    
    if [[ $CURRENT_POS -gt $LAST_POS ]]; then
        # Read new lines
        tail -c +$((LAST_POS + 1)) "$LOG_FILE" | while IFS= read -r line; do
            if echo "$line" | grep -qE "$PATTERN"; then
                NOW=$(date +%s)
                if [[ $((NOW - LAST_ALERT)) -ge $COOLDOWN ]]; then
                    echo "ALERT: Pattern matched in $LOG_FILE"
                    echo "Line: $line"
                    
                    if [[ -n "$WEBHOOK" ]]; then
                        PAYLOAD=$(jq -n --arg text "Log Alert: $line" '{text: $text}')
                        curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK" >/dev/null || true
                    fi
                    
                    LAST_ALERT=$NOW
                    echo $LAST_ALERT > "$COOLDOWN_FILE"
                fi
            fi
        done
        LAST_POS=$CURRENT_POS
    fi
    
    sleep "$INTERVAL"
done