#!/bin/bash
# daily_summary.sh - Send daily system summary notification
# Usage: ./daily_summary.sh [--channel gotify|ntfy|discord|slack|email] [--webhook URL]

set -euo pipefail

CHANNEL="gotify"
WEBHOOK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --channel) CHANNEL="$2"; shift 2 ;;
        --webhook) WEBHOOK="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d')
UPTIME=$(uptime -p)

# Disk usage
DISK_USAGE=$(df -h /mnt/user 2>/dev/null | tail -1 | awk '{print $5 " used of " $2}' || echo "N/A")

# Memory
MEM_USAGE=$(free -h | awk 'NR==2{print $3 " / " $2}')

# Docker stats
if command -v docker &>/dev/null; then
    DOCKER_RUNNING=$(docker ps -q | wc -l)
    DOCKER_TOTAL=$(docker ps -aq | wc -l)
    DOCKER_UNHEALTHY=$(docker ps --filter "health=unhealthy" -q | wc -l)
    DOCKER_INFO="$DOCKER_RUNNING/$DOCKER_TOTAL running"
    [[ $DOCKER_UNHEALTHY -gt 0 ]] && DOCKER_INFO="$DOCKER_INFO, $DOCKER_UNHEALTHY unhealthy"
else
    DOCKER_INFO="Not installed"
fi

# Array status
if [[ -f /proc/mdstat ]]; then
    ARRAY_STATUS=$(grep -c "active raid" /proc/mdstat || echo 0)
    ARRAY_INFO="$ARRAY_STATUS arrays active"
else
    ARRAY_INFO="N/A"
fi

# Temperature (first disk)
DISK_TEMP=$(smartctl -A /dev/sda 2>/dev/null | grep -i "Temperature_Celsius" | awk '{print $10 "°C"}' || echo "N/A")

MESSAGE="📊 **Daily Summary - $HOSTNAME** ($DATE)

⏰ **Uptime**: $UPTIME
💾 **Disk**: $DISK_USAGE
🧠 **Memory**: $MEM_USAGE
🐳 **Docker**: $DOCKER_INFO
💿 **Array**: $ARRAY_INFO
🌡️ **Temp**: $DISK_TEMP"

TITLE="Daily Summary - $HOSTNAME"

# Use notify script if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/01_notify.sh" ]]; then
    "$SCRIPT_DIR/01_notify.sh" --title "$TITLE" --message "$MESSAGE" --channel "$CHANNEL"
else
    # Fallback
    echo "$MESSAGE"
fi