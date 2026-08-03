#!/bin/bash
# parity_check_schedule.sh - Schedule and monitor parity checks
# Usage: ./parity_check_schedule.sh [--start|--status|--cancel] [--schedule cron] [--notify]

set -euo pipefail

ACTION="status"
SCHEDULE=""
NOTIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --start) ACTION="start"; shift ;;
        --status) ACTION="status"; shift ;;
        --cancel) ACTION="cancel"; shift ;;
        --schedule) SCHEDULE="$2"; shift 2 ;;
        --notify) NOTIFY=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

PARITY_CMD="/usr/local/sbin/mdadm_sync"
STATUS_FILE="/var/tmp/parity_check_status"

case $ACTION in
    start)
        echo "Starting parity check..."
        if [[ -f "$STATUS_FILE" ]] && grep -q "RUNNING" "$STATUS_FILE"; then
            echo "Parity check already running"
            exit 1
        fi
        
        echo "RUNNING:$(date +%s)" > "$STATUS_FILE"
        
        if [[ "$NOTIFY" == true ]]; then
            notify-send "Parity Check" "Parity check started" 2>/dev/null || true
        fi
        
        # Run in background
        nohup $PARITY_CMD --check >> /var/log/parity_check.log 2>&1 &
        PID=$!
        echo $PID >> "$STATUS_FILE"
        
        echo "Parity check started (PID: $PID)"
        ;;
        
    status)
        if [[ -f "$STATUS_FILE" ]]; then
            cat "$STATUS_FILE"
        else
            echo "No parity check status file found"
        fi
        
        # Check if process is still running
        if [[ -f "$STATUS_FILE" ]]; then
            PID=$(tail -n1 "$STATUS_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                echo "Status: RUNNING (PID: $PID)"
            else
                echo "Status: COMPLETED/FAILED"
                if [[ "$NOTIFY" == true ]]; then
                    notify-send "Parity Check" "Parity check completed" 2>/dev/null || true
                fi
            fi
        fi
        ;;
        
    cancel)
        if [[ -f "$STATUS_FILE" ]]; then
            PID=$(tail -n1 "$STATUS_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID"
                echo "CANCELLED:$(date +%s)" > "$STATUS_FILE"
                echo "Parity check cancelled"
                if [[ "$NOTIFY" == true ]]; then
                    notify-send "Parity Check" "Parity check cancelled" 2>/dev/null || true
                fi
            else
                echo "No running parity check to cancel"
            fi
        else
            echo "No parity check status file found"
        fi
        ;;
esac

# Schedule if requested
if [[ -n "$SCHEDULE" ]]; then
    CRON_ENTRY="$SCHEDULE $0 --start --notify"
    (crontab -l 2>/dev/null | grep -v "$0 --start"; echo "$CRON_ENTRY") | crontab -
    echo "Scheduled parity check: $SCHEDULE"
fi