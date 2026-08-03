#!/bin/bash
# memory_pressure_monitor.sh - Monitor memory pressure and take action
# Usage: ./memory_pressure_monitor.sh [--threshold N] [--action kill|notify|swap] [--interval N] [--exclude process1,process2]

set -euo pipefail

THRESHOLD=85
ACTION="notify"
INTERVAL=60
EXCLUDE_PROCESSES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --action) ACTION="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --exclude) EXCLUDE_PROCESSES="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

IFS=',' read -ra EXCLUDE <<< "$EXCLUDE_PROCESSES"

should_exclude() {
    local proc="$1"
    for excl in "${EXCLUDE[@]}"; do
        [[ "$proc" == *"$excl"* ]] && return 0
    done
    return 1
}

echo "=== Memory Pressure Monitor ==="
echo "Threshold: ${THRESHOLD}%"
echo "Action: $ACTION"
echo "Interval: ${INTERVAL}s"
echo "Excluded: ${EXCLUDE_PROCESSES:-none}"

while true; do
    MEM_USED=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [[ $MEM_USED -ge $THRESHOLD ]]; then
        echo "$(date): Memory pressure detected: ${MEM_USED}%"
        
        # Find top memory consumers
        TOP_PROCS=$(ps aux --sort=-%mem | head -10 | tail -n +2)
        echo "Top memory consumers:"
        echo "$TOP_PROCS"
        
        case $ACTION in
            notify)
                notify-send "Memory Pressure" "Memory at ${MEM_USED}%" 2>/dev/null || true
                ;;
            kill)
                # Kill highest non-excluded process
                while IFS= read -r line; do
                    PID=$(echo "$line" | awk '{print $2}')
                    PROC=$(echo "$line" | awk '{print $11}')
                    if ! should_exclude "$PROC"; then
                        echo "Killing $PROC (PID: $PID)"
                        kill -9 "$PID"
                        break
                    fi
                done <<< "$TOP_PROCS"
                ;;
            swap)
                echo "Triggering swap..."
                sync
                echo 3 > /proc/sys/vm/drop_caches
                ;;
        esac
    else
        echo "$(date): Memory OK: ${MEM_USED}%"
    fi
    
    sleep "$INTERVAL"
done