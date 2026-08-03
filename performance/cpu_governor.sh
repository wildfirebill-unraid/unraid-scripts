#!/bin/bash
# cpu_governor.sh - Manage CPU frequency scaling governor
# Usage: ./cpu_governor.sh [--governor performance|powersave|ondemand|conservative] [--cpu N] [--status]

set -euo pipefail

GOVERNOR=""
CPU="all"
SHOW_STATUS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --governor) GOVERNOR="$2"; shift 2 ;;
        --cpu) CPU="$2"; shift 2 ;;
        --status) SHOW_STATUS=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ "$SHOW_STATUS" == true ]]; then
    echo "=== CPU Governor Status ==="
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        CPU_NUM=$(basename "$cpu" | sed 's/cpu//')
        CURRENT=$(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null || echo "N/A")
        AVAILABLE=$(cat "$cpu/cpufreq/scaling_available_governors" 2>/dev/null || echo "N/A")
        CUR_FREQ=$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null || echo "N/A")
        MAX_FREQ=$(cat "$cpu/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo "N/A")
        echo "CPU $CPU_NUM: $CURRENT (available: $AVAILABLE) | Current: $((CUR_FREQ/1000))MHz Max: $((MAX_FREQ/1000))MHz"
    done
    exit 0
fi

if [[ -z "$GOVERNOR" ]]; then
    echo "Usage: $0 --governor performance|powersave|ondemand|conservative [--cpu N]"
    exit 1
fi

VALID_GOVERNORS=("performance" "powersave" "ondemand" "conservative" "schedutil")
if [[ ! " ${VALID_GOVERNORS[@]} " =~ " ${GOVERNOR} " ]]; then
    echo "Invalid governor: $GOVERNOR"
    echo "Valid: ${VALID_GOVERNORS[*]}"
    exit 1
fi

echo "=== Setting CPU Governor ==="
echo "Governor: $GOVERNOR"

if [[ "$CPU" == "all" ]]; then
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        CPU_NUM=$(basename "$cpu" | sed 's/cpu//')
        echo "$GOVERNOR" | tee "$cpu/cpufreq/scaling_governor" >/dev/null
        echo "Set CPU $CPU_NUM to $GOVERNOR"
    done
else
    if [[ -d "/sys/devices/system/cpu/cpu$CPU" ]]; then
        echo "$GOVERNOR" | tee "/sys/devices/system/cpu/cpu$CPU/cpufreq/scaling_governor" >/dev/null
        echo "Set CPU $CPU to $GOVERNOR"
    else
        echo "CPU $CPU not found"
        exit 1
    fi
fi

echo "Done"