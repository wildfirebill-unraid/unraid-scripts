#!/bin/bash
# docker_resource_monitor.sh - Monitor Docker container resource usage
# Usage: ./docker_resource_monitor.sh [--interval N] [--alert-cpu N] [--alert-mem N] [--log-file /path/to/log]

set -euo pipefail

INTERVAL=60
ALERT_CPU=80
ALERT_MEM=80
LOG_FILE="/var/log/docker_resources.log"

while [[ $# -gt 0 ]]; do
    case $1 in
        --interval) INTERVAL="$2"; shift 2 ;;
        --alert-cpu) ALERT_CPU="$2"; shift 2 ;;
        --alert-mem) ALERT_MEM="$2"; shift 2 ;;
        --log-file) LOG_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Docker Resource Monitor ==="
echo "Interval: ${INTERVAL}s"
echo "CPU Alert: ${ALERT_CPU}%"
echo "Memory Alert: ${ALERT_MEM}%"
echo "Log file: $LOG_FILE"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemPerc}},{{.MemUsage}}" | while IFS=',' read -r name cpu mem mem_usage; do
        cpu_val=${cpuperc%\%}
        mem_val=${memperc%\%}
        
        cpu_val=${cpu_val//,/}
        mem_val=${mem_val//,/}
        
        LOG_ENTRY="$TIMESTAMP,$name,$cpu_val,$mem_val,$mem_usage"
        echo "$LOG_ENTRY" >> "$LOG_FILE"
        
        ALERTS=()
        if (( $(echo "$cpu_val > $ALERT_CPU" | bc -l) )); then
            ALERTS+=("HIGH CPU: ${cpu_val}%")
        fi
        if (( $(echo "$mem_val > $ALERT_MEM" | bc -l) )); then
            ALERTS+=("HIGH MEM: ${mem_val}%")
        fi
        
        if [[ ${#ALERTS[@]} -gt 0 ]]; then
            echo "ALERT [$TIMESTAMP] $name: ${ALERTS[*]}" | tee -a "$LOG_FILE"
        fi
    done
    
    sleep "$INTERVAL"
done