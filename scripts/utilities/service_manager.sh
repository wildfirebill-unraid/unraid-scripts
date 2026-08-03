#!/bin/bash
# service_manager.sh - Manage systemd services with Unraid-friendly features
# Usage: ./service_manager.sh [--list] [--status name] [--start name] [--stop name] [--restart name] [--enable name] [--disable name]

set -euo pipefail

ACTION="list"
NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --list) ACTION="list"; shift ;;
        --status) ACTION="status"; NAME="$2"; shift 2 ;;
        --start) ACTION="start"; NAME="$2"; shift 2 ;;
        --stop) ACTION="stop"; NAME="$2"; shift 2 ;;
        --restart) ACTION="restart"; NAME="$2"; shift 2 ;;
        --enable) ACTION="enable"; NAME="$2"; shift 2 ;;
        --disable) ACTION="disable"; NAME="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SERVICES_DIR="/etc/systemd/system"
UNRAID_SERVICES=("docker" "sshd" "nginx" "smbd" "nfs-server" "avahi-daemon" "wsdd" "telegraf" "prometheus-node-exporter")

case $ACTION in
    list)
        echo "=== Systemd Services ==="
        echo "--- Unraid Core Services ---"
        for svc in "${UNRAID_SERVICES[@]}"; do
            if systemctl list-unit-files | grep -q "^$svc.service"; then
                STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
                ENABLED=$(systemctl is-enabled "$svc" 2>/dev/null || echo "disabled")
                printf "  %-30s %-10s %s\n" "$svc" "[$STATUS]" "($ENABLED)"
            fi
        done
        
        echo ""
        echo "--- Custom Services ---"
        systemctl list-unit-files --type=service | grep -E "\.service\s+(enabled|disabled)" | grep -v "@" | while read -r line; do
            SVC=$(echo "$line" | awk '{print $1}')
            if [[ ! " ${UNRAID_SERVICES[@]} " =~ " ${SVC%.service} " ]]; then
                STATUS=$(systemctl is-active "$SVC" 2>/dev/null || echo "inactive")
                ENABLED=$(echo "$line" | awk '{print $2}')
                printf "  %-30s %-10s %s\n" "$SVC" "[$STATUS]" "($ENABLED)"
            fi
        done
        ;;
        
    status)
        if [[ -z "$NAME" ]]; then
            echo "Usage: $0 --status name"
            exit 1
        fi
        systemctl status "$NAME" --no-pager
        ;;
        
    start|stop|restart|enable|disable)
        if [[ -z "$NAME" ]]; then
            echo "Usage: $0 --$ACTION name"
            exit 1
        fi
        systemctl "$ACTION" "$NAME"
        echo "Service $NAME: $ACTION completed"
        ;;
esac