#!/bin/bash
# restart_unhealthy_containers.sh - Restart Docker containers that are unhealthy
# Usage: ./restart_unhealthy_containers.sh [--interval N] [--max-restarts N] [--notify]

set -euo pipefail

INTERVAL=300
MAX_RESTARTS=3
NOTIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --interval) INTERVAL="$2"; shift 2 ;;
        --max-restarts) MAX_RESTARTS="$2"; shift 2 ;;
        --notify) NOTIFY=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

RESTART_COUNT_FILE="/tmp/docker_restart_counts"
declare -A RESTART_COUNTS

if [[ -f "$RESTART_COUNT_FILE" ]]; then
    while IFS='=' read -r key value; do
        RESTART_COUNTS["$key"]="$value"
    done < "$RESTART_COUNT_FILE"
fi

echo "=== Unhealthy Container Monitor ==="
echo "Check interval: ${INTERVAL}s"
echo "Max restarts per container: $MAX_RESTARTS"

while true; do
    unhealthy_containers=$(docker ps --filter "health=unhealthy" --format "{{.Names}}")
    
    if [[ -n "$unhealthy_containers" ]]; then
        echo "$(date): Found unhealthy containers:"
        echo "$unhealthy_containers"
        
        while IFS= read -r container; do
            count=${RESTART_COUNTS[$container]:-0}
            
            if [[ $count -ge $MAX_RESTARTS ]]; then
                echo "  $container: Max restarts ($MAX_RESTARTS) reached, skipping"
                if [[ "$NOTIFY" == true ]]; then
                    notify-send "Docker Alert" "$container has reached max restarts" 2>/dev/null || true
                fi
                continue
            fi
            
            echo "  Restarting $container (attempt $((count + 1))/$MAX_RESTARTS)"
            docker restart "$container"
            RESTART_COUNTS[$container]=$((count + 1))
            
            if [[ "$NOTIFY" == true ]]; then
                notify-send "Docker Restart" "Restarted unhealthy container: $container" 2>/dev/null || true
            fi
        done <<< "$unhealthy_containers"
        
        # Save restart counts
        > "$RESTART_COUNT_FILE"
        for key in "${!RESTART_COUNTS[@]}"; do
            echo "$key=${RESTART_COUNTS[$key]}" >> "$RESTART_COUNT_FILE"
        done
    else
        echo "$(date): All containers healthy"
    fi
    
    sleep "$INTERVAL"
done