#!/bin/bash
# io_scheduler.sh - Set I/O scheduler for block devices
# Usage: ./io_scheduler.sh [--device /dev/sdX] [--scheduler none|mq-deadline|kyber|bfq] [--status]

set -euo pipefail

DEVICE=""
SCHEDULER=""
SHOW_STATUS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --device) DEVICE="$2"; shift 2 ;;
        --scheduler) SCHEDULER="$2"; shift 2 ;;
        --status) SHOW_STATUS=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ "$SHOW_STATUS" == true ]]; then
    echo "=== I/O Scheduler Status ==="
    for dev in /sys/block/sd*; do
        DEV_NAME=$(basename "$dev")
        if [[ -f "$dev/queue/scheduler" ]]; then
            CURRENT=$(cat "$dev/queue/scheduler" | grep -o '\[.*\]' | tr -d '[]')
            AVAILABLE=$(cat "$dev/queue/scheduler" | tr -d '[]' | xargs)
            ROTATIONAL=$(cat "$dev/queue/rotational" 2>/dev/null || echo "?")
            TYPE=$([[ "$ROTATIONAL" == "0" ]] && echo "SSD/NVMe" || echo "HDD")
            echo "$DEV_NAME ($TYPE): $CURRENT (available: $AVAILABLE)"
        fi
    done
    exit 0
fi

if [[ -z "$DEVICE" || -z "$SCHEDULER" ]]; then
    echo "Usage: $0 --device /dev/sdX --scheduler none|mq-deadline|kyber|bfq"
    exit 1
fi

VALID_SCHEDULERS=("none" "mq-deadline" "kyber" "bfq")
if [[ ! " ${VALID_SCHEDULERS[@]} " =~ " ${SCHEDULER} " ]]; then
    echo "Invalid scheduler: $SCHEDULER"
    echo "Valid: ${VALID_SCHEDULERS[*]}"
    exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
    echo "Device not found: $DEVICE"
    exit 1
fi

DEV_NAME=$(basename "$DEVICE")
SCHED_PATH="/sys/block/$DEV_NAME/queue/scheduler"

if [[ ! -f "$SCHED_PATH" ]]; then
    echo "Scheduler not configurable for $DEVICE"
    exit 1
fi

CURRENT=$(cat "$SCHED_PATH" | grep -o '\[.*\]' | tr -d '[]')
echo "=== Setting I/O Scheduler ==="
echo "Device: $DEVICE"
echo "Current: $CURRENT"
echo "New: $SCHEDULER"

echo "$SCHEDULER" > "$SCHED_PATH"
NEW=$(cat "$SCHED_PATH" | grep -o '\[.*\]' | tr -d '[]')
echo "Applied: $NEW"

# Persist via udev rule
UDEV_RULE="/etc/udev/rules.d/60-io-scheduler.rules"
echo "ACTION==\"add|change\", KERNEL==\"$DEV_NAME\", ATTR{queue/scheduler}=\"$SCHEDULER\"" > "$UDEV_RULE"
echo "Udev rule created: $UDEV_RULE"