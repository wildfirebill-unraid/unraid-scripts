#!/bin/bash
# check_smart_status.sh - Check SMART status of all disks
# Usage: ./check_smart_status.sh [--device /dev/sdX] [--alert-threshold N] [--json]

set -euo pipefail

DEVICE=""
ALERT_THRESHOLD=10
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --device) DEVICE="$2"; shift 2 ;;
        --alert-threshold) ALERT_THRESHOLD="$2"; shift 2 ;;
        --json) JSON_OUTPUT=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== SMART Status Check ==="

DEVICES=()
if [[ -n "$DEVICE" ]]; then
    DEVICES=("$DEVICE")
else
    # Find all block devices
    mapfile -t DEVICES < <(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}')
fi

ALERTS=0
RESULTS=()

for dev in "${DEVICES[@]}"; do
    if [[ ! -b "$dev" ]]; then
        continue
    fi
    
    # Get basic info
    MODEL=$(smartctl -i "$dev" 2>/dev/null | grep "Device Model" | cut -d: -f2 | xargs || echo "Unknown")
    SERIAL=$(smartctl -i "$dev" 2>/dev/null | grep "Serial Number" | cut -d: -f2 | xargs || echo "Unknown")
    
    # Run short self-test if not already running
    smartctl -t short "$dev" >/dev/null 2>&1 || true
    
    # Get SMART attributes
    SMART_OUTPUT=$(smartctl -A "$dev" 2>/dev/null || echo "")
    
    # Check critical attributes
    REALLOCATED=$(echo "$SMART_OUTPUT" | grep -i "Reallocated_Sector" | awk '{print $10}' || echo 0)
    CURRENT_PENDING=$(echo "$SMART_OUTPUT" | grep -i "Current_Pending_Sector" | awk '{print $10}' || echo 0)
    OFFLINE_UNCORRECTABLE=$(echo "$SMART_OUTPUT" | grep -i "Offline_Uncorrectable" | awk '{print $10}' || echo 0)
    UDMA_CRC_ERRORS=$(echo "$SMART_OUTPUT" | grep -i "UDMA_CRC_Error_Count" | awk '{print $10}' || echo 0)
    
    STATUS="OK"
    if [[ $REALLOCATED -gt $ALERT_THRESHOLD ]] || [[ $CURRENT_PENDING -gt $ALERT_THRESHOLD ]] || [[ $OFFLINE_UNCORRECTABLE -gt $ALERT_THRESHOLD ]] || [[ $UDMA_CRC_ERRORS -gt $ALERT_THRESHOLD ]]; then
        STATUS="WARNING"
        ALERTS=$((ALERTS + 1))
    fi
    
    RESULT="Device: $dev | Model: $MODEL | Serial: $SERIAL | Status: $STATUS | Reallocated: $REALLOCATED | Pending: $CURRENT_PENDING | Offline: $OFFLINE_UNCORRECTABLE | CRC: $UDMA_CRC_ERRORS"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        RESULTS+=("{\"device\":\"$dev\",\"model\":\"$MODEL\",\"serial\":\"$SERIAL\",\"status\":\"$STATUS\",\"reallocated\":$REALLOCATED,\"pending\":$CURRENT_PENDING,\"offline\":$OFFLINE_UNCORRECTABLE,\"crc\":$UDMA_CRC_ERRORS}")
    else
        echo "$RESULT"
    fi
done

if [[ "$JSON_OUTPUT" == true ]]; then
    echo "["$(IFS=,; echo "${RESULTS[*]}")"]"
fi

echo ""
echo "Total devices checked: ${#DEVICES[@]}"
echo "Alerts: $ALERTS"

[[ $ALERTS -gt 0 ]] && exit 1 || exit 0