#!/bin/bash
# disk-health-check.sh
# Monitor Unraid disk health and send alerts
# Can be run via User Scripts plugin on schedule

set -euo pipefail

# Configuration
ALERT_TEMP=50          # Alert if disk temp exceeds this (Celsius)
ALERT_REALLOCATED=10   # Alert if reallocated sectors > this
DISCORD_WEBHOOK=""     # Optional: Discord webhook URL for notifications
LOG_FILE="/var/log/disk-health.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local message="$1"
    log "${RED}ALERT: $message${NC}"
    
    if [[ -n "$DISCORD_WEBHOOK" ]]; then
        curl -s -H "Content-Type: application/json" \
            -d "{\"content\": \"⚠️ **Unraid Disk Alert**\\n$message\"}" \
            "$DISCORD_WEBHOOK" >/dev/null 2>&1 || true
    fi
}

check_smart() {
    local disk="$1"
    local short_name=$(basename "$disk")
    
    # Get SMART data
    smart_data=$(smartctl -A "$disk" 2>/dev/null) || {
        warning "Could not read SMART for $short_name"
        return
    }
    
    # Check temperature
    temp=$(echo "$smart_data" | awk '/Temperature_Celsius|Airflow_Temperature_Cel/ {print $10}' | head -1)
    if [[ -n "$temp" && "$temp" -gt "$ALERT_TEMP" ]]; then
        send_alert "Disk **$short_name** temperature: **${temp}°C** (threshold: ${ALERT_TEMP}°C)"
    fi
    
    # Check reallocated sectors
    reallocated=$(echo "$smart_data" | awk '/Reallocated_Sector_Ct/ {print $10}')
    if [[ -n "$reallocated" && "$reallocated" -gt "$ALERT_REALLOCATED" ]]; then
        send_alert "Disk **$short_name** has **$reallocated** reallocated sectors (threshold: $ALERT_REALLOCATED)"
    fi
    
    # Check pending sectors
    pending=$(echo "$smart_data" | awk '/Current_Pending_Sector/ {print $10}')
    if [[ -n "$pending" && "$pending" -gt 0 ]]; then
        send_alert "Disk **$short_name** has **$pending** pending sectors"
    fi
    
    # Check offline uncorrectable
    offline=$(echo "$smart_data" | awk '/Offline_Uncorrectable/ {print $10}')
    if [[ -n "$offline" && "$offline" -gt 0 ]]; then
        send_alert "Disk **$short_name** has **$offline** offline uncorrectable sectors"
    fi
    
    log "${GREEN}✓${NC} $short_name: OK"
}

# Main
log "Starting disk health check..."

# Find all disks (sd* and nvme*)
for disk in /dev/sd[a-z] /dev/nvme*n1; do
    if [[ -b "$disk" ]]; then
        check_smart "$disk"
    fi
done

log "Disk health check completed"