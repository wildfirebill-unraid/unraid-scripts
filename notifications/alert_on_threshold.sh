#!/bin/bash
# alert_on_threshold.sh - Alert when metrics exceed thresholds
# Usage: ./alert_on_threshold.sh --metric cpu|mem|disk|temp --threshold N [--channel gotify|ntfy|discord] [--webhook URL] [--interval N]

set -euo pipefail

METRIC=""
THRESHOLD=""
CHANNEL="gotify"
WEBHOOK=""
INTERVAL=60
COOLDOWN=3600

while [[ $# -gt 0 ]]; do
    case $1 in
        --metric) METRIC="$2"; shift 2 ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        --webhook) WEBHOOK="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --cooldown) COOLDOWN="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$METRIC" || -z "$THRESHOLD" ]]; then
    echo "Usage: $0 --metric cpu|mem|disk|temp --threshold N [options]"
    exit 1
fi

COOLDOWN_FILE="/tmp/alert_cooldown_${METRIC}_${THRESHOLD}"
LAST_ALERT=0

if [[ -f "$COOLDOWN_FILE" ]]; then
    LAST_ALERT=$(cat "$COOLDOWN_FILE")
fi

HOSTNAME=$(hostname)

get_metric_value() {
    case $METRIC in
        cpu)
            # CPU load per core
            LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
            CORES=$(nproc)
            echo "scale=2; $LOAD / $CORES" | bc
            ;;
        mem)
            # Memory usage percentage
            free | awk 'NR==2{printf "%.1f", $3*100/$2}'
            ;;
        disk)
            # Root disk usage percentage
            df / | awk 'NR==2{print $5}' | sed 's/%//'
            ;;
        temp)
            # First disk temperature
            smartctl -A /dev/sda 2>/dev/null | grep -i "Temperature_Celsius" | awk '{print $10}' || echo 0
            ;;
        *)
            echo 0
            ;;
    esac
}

send_alert() {
    local value=$1
    local message="🚨 **Threshold Alert** - $HOSTNAME
**Metric**: $METRIC
**Value**: $value
**Threshold**: $THRESHOLD
**Time**: $(date)"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/01_notify.sh" ]]; then
        "$SCRIPT_DIR/01_notify.sh" --title "Threshold Alert: $METRIC" --message "$message" --channel "$CHANNEL" --priority 10
    else
        echo "$message"
    fi
}

echo "=== Threshold Alert Monitor ==="
echo "Metric: $METRIC"
echo "Threshold: $THRESHOLD"
echo "Interval: ${INTERVAL}s"
echo "Cooldown: ${COOLDOWN}s"

while true; do
    VALUE=$(get_metric_value)
    
    # Compare (handle decimals for cpu)
    ALERT=false
    if [[ "$METRIC" == "cpu" ]]; then
        if (( $(echo "$VALUE > $THRESHOLD" | bc -l) )); then
            ALERT=true
        fi
    else
        if [[ $VALUE -gt $THRESHOLD ]]; then
            ALERT=true
        fi
    fi
    
    if [[ "$ALERT" == true ]]; then
        NOW=$(date +%s)
        if [[ $((NOW - LAST_ALERT)) -ge $COOLDOWN ]]; then
            send_alert "$VALUE"
            LAST_ALERT=$NOW
            echo $LAST_ALERT > "$COOLDOWN_FILE"
        fi
    fi
    
    sleep "$INTERVAL"
done