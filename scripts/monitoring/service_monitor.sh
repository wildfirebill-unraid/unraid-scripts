#!/bin/bash
# service_monitor.sh - Monitor critical services and auto-restart
# Usage: ./service_monitor.sh --service name [--interval N] [--restart-cmd "cmd"] [--max-restarts N] [--notify]

set -euo pipefail

SERVICE=""
INTERVAL=60
RESTART_CMD=""
MAX_RESTARTS=3
NOTIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --service) SERVICE="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --restart-cmd) RESTART_CMD="$2"; shift 2 ;;
        --max-restarts) MAX_RESTARTS="$2"; shift 2 ;;
        --notify) NOTIFY=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SERVICE" ]]; then
    echo "Usage: $0 --service name [options]"
    exit 1
fi

RESTART_COUNT_FILE="/tmp/service_monitor_${SERVICE//\//_}_restarts"
RESTART_COUNT=0

if [[ -f "$RESTART_COUNT_FILE" ]]; then
    RESTART_COUNT=$(cat "$RESTART_COUNT_FILE")
fi

echo "=== Service Monitor ==="
echo "Service: $SERVICE"
echo "Interval: ${INTERVAL}s"
echo "Max restarts: $MAX_RESTARTS"
echo "Current restarts: $RESTART_COUNT"

check_service() {
    if systemctl is-active --quiet "$SERVICE"; then
        return 0
    else
        return 1
    fi
}

while true; do
    if check_service; then
        echo "$(date): $SERVICE is running"
        # Reset restart count on successful check
        if [[ $RESTART_COUNT -gt 0 ]]; then
            RESTART_COUNT=0
            echo 0 > "$RESTART_COUNT_FILE"
        fi
    else
        echo "$(date): $SERVICE is DOWN"
        
        if [[ $RESTART_COUNT -ge $MAX_RESTARTS ]]; then
            echo "Max restarts ($MAX_RESTARTS) reached. Alerting..."
            if [[ "$NOTIFY" == true ]]; then
                notify-send "Service Alert" "$SERVICE failed after $MAX_RESTARTS restarts" 2>/dev/null || true
            fi
            sleep "$INTERVAL"
            continue
        fi
        
        echo "Attempting restart ($((RESTART_COUNT + 1))/$MAX_RESTARTS)..."
        
        if [[ -n "$RESTART_CMD" ]]; then
            eval "$RESTART_CMD"
        else
            systemctl restart "$SERVICE"
        fi
        
        RESTART_COUNT=$((RESTART_COUNT + 1))
        echo $RESTART_COUNT > "$RESTART_COUNT_FILE"
        
        if [[ "$NOTIFY" == true ]]; then
            notify-send "Service Restart" "Restarted $SERVICE (attempt $RESTART_COUNT/$MAX_RESTARTS)" 2>/dev/null || true
        fi
        
        sleep 10
        
        if check_service; then
            echo "$(date): $SERVICE restarted successfully"
        else
            echo "$(date): $SERVICE restart FAILED"
        fi
    fi
    
    sleep "$INTERVAL"
done