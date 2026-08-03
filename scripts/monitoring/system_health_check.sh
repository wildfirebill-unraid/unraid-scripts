#!/bin/bash
# system_health_check.sh - Comprehensive system health check
# Usage: ./system_health_check.sh [--format text|json] [--output /path] [--alert-webhook URL]

set -euo pipefail

FORMAT="text"
OUTPUT=""
ALERT_WEBHOOK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --format) FORMAT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --alert-webhook) ALERT_WEBHOOK="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

REPORT_FILE="${OUTPUT:-/tmp/health_check_$(date +%Y%m%d_%H%M%S).txt}"
ALERTS=()

check_cpu() {
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    CORES=$(nproc)
    LOAD_PER_CORE=$(echo "scale=2; $LOAD / $CORES" | bc)
    
    if (( $(echo "$LOAD_PER_CORE > 2.0" | bc -l) )); then
        ALERTS+=("CPU load high: $LOAD_PER_CORE per core")
    fi
    echo "CPU: $LOAD_PER_CORE per core ($LOAD total, $CORES cores)"
}

check_memory() {
    MEM_INFO=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    MEM_AVAIL=$(free -m | awk 'NR==2{print $7}')
    
    if (( $(echo "$MEM_INFO > 90" | bc -l) )); then
        ALERTS+=("Memory usage high: ${MEM_INFO}%")
    fi
    echo "Memory: ${MEM_INFO}% used, ${MEM_AVAIL}MB available"
}

check_disk() {
    df -hP | tail -n +2 | while read -r line; do
        USE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        MOUNT=$(echo "$line" | awk '{print $6}')
        if [[ $USE -gt 90 ]]; then
            ALERTS+=("Disk $MOUNT at ${USE}%")
        fi
        echo "Disk $MOUNT: ${USE}%"
    done
}

check_docker() {
    if command -v docker &>/dev/null; then
        RUNNING=$(docker ps -q | wc -l)
        UNHEALTHY=$(docker ps --filter "health=unhealthy" -q | wc -l)
        STOPPED=$(docker ps -a -q -f status=exited | wc -l)
        
        if [[ $UNHEALTHY -gt 0 ]]; then
            ALERTS+=("$UNHEALTHY Docker containers unhealthy")
        fi
        if [[ $STOPPED -gt 0 ]]; then
            ALERTS+=("$STOPPED Docker containers stopped")
        fi
        echo "Docker: $RUNNING running, $UNHEALTHY unhealthy, $STOPPED stopped"
    else
        echo "Docker: Not installed"
    fi
}

check_network() {
    # Check internet connectivity
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "Network: Internet reachable"
    else
        ALERTS+=("No internet connectivity")
        echo "Network: No internet"
    fi
    
    # Check local gateway
    GW=$(ip route | grep default | awk '{print $3}')
    if ping -c 1 -W 1 "$GW" &>/dev/null; then
        echo "Gateway ($GW): Reachable"
    else
        ALERTS+=("Gateway unreachable")
        echo "Gateway ($GW): Unreachable"
    fi
}

check_services() {
    SERVICES=("ssh" "nginx" "docker" "smbd" "nfs-server")
    for svc in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo "Service $svc: Active"
        elif systemctl list-unit-files | grep -q "^$svc.service"; then
            ALERTS+=("Service $svc is inactive")
            echo "Service $svc: Inactive"
        fi
    done
}

# Run checks
{
    echo "=== System Health Check ==="
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo ""
    
    echo "--- CPU ---"
    check_cpu
    echo ""
    
    echo "--- Memory ---"
    check_memory
    echo ""
    
    echo "--- Disk ---"
    check_disk
    echo ""
    
    echo "--- Docker ---"
    check_docker
    echo ""
    
    echo "--- Network ---"
    check_network
    echo ""
    
    echo "--- Services ---"
    check_services
    echo ""
    
    echo "--- Alerts ---"
    if [[ ${#ALERTS[@]} -gt 0 ]]; then
        for alert in "${ALERTS[@]}"; do
            echo "ALERT: $alert"
        done
    else
        echo "No alerts"
    fi
} > "$REPORT_FILE"

# Send webhook if configured
if [[ -n "$ALERT_WEBHOOK" && ${#ALERTS[@]} -gt 0 ]]; then
    PAYLOAD=$(jq -n --arg text "$(printf '%s\n' "${ALERTS[@]}")" '{text: $text}')
    curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$ALERT_WEBHOOK" >/dev/null || true
fi

cat "$REPORT_FILE"
[[ ${#ALERTS[@]} -gt 0 ]] && exit 1 || exit 0