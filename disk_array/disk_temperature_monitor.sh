#!/bin/bash
# disk_temperature_monitor.sh - Monitor disk temperatures and alert
# Usage: ./disk_temperature_monitor.sh [--interval N] [--warn-temp N] [--crit-temp N] [--log-file /path] [--daemon]

set -euo pipefail

INTERVAL=300
WARN_TEMP=45
CRIT_TEMP=55
LOG_FILE="/var/log/disk_temps.log"
DAEMON=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --interval) INTERVAL="$2"; shift 2 ;;
        --warn-temp) WARN_TEMP="$2"; shift 2 ;;
        --crit-temp) CRIT_TEMP="$2"; shift 2 ;;
        --log-file) LOG_FILE="$2"; shift 2 ;;
        --daemon) DAEMON=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

echo "=== Disk Temperature Monitor ==="
echo "Interval: ${INTERVAL}s"
echo "Warning: ${WARN_TEMP}°C"
echo "Critical: ${CRIT_TEMP}°C"
echo "Log: $LOG_FILE"

check_temps() {
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get all disks
    lsblk -d -n -o NAME | while read -r disk; do
        DEVICE="/dev/$disk"
        TEMP=$(smartctl -A "$DEVICE" 2>/dev/null | grep -i "Temperature_Celsius" | awk '{print $10}' || echo "")
        
        if [[ -n "$TEMP" && "$TEMP" =~ ^[0-9]+$ ]]; then
            LOG_ENTRY="$TIMESTAMP,$disk,$TEMP"
            echo "$LOG_ENTRY" >> "$LOG_FILE"
            
            if [[ $TEMP -ge $CRIT_TEMP ]]; then
                echo "CRITICAL [$TIMESTAMP] $disk: ${TEMP}°C" | tee -a "$LOG_FILE"
                notify-send "Disk Critical" "$disk at ${TEMP}°C" 2>/dev/null || true
            elif [[ $TEMP -ge $WARN_TEMP ]]; then
                echo "WARNING [$TIMESTAMP] $disk: ${TEMP}°C" | tee -a "$LOG_FILE"
            fi
        fi
    done
}

if [[ "$DAEMON" == true ]]; then
    while true; do
        check_temps
        sleep "$INTERVAL"
    done
else
    check_temps
fi