#!/bin/bash
# fail2ban_status.sh - Check and manage fail2ban status
# Usage: ./fail2ban_status.sh [--jail name] [--unban ip] [--status] [--logs]

set -euo pipefail

JAIL=""
UNBAN_IP=""
SHOW_STATUS=false
SHOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --jail) JAIL="$2"; shift 2 ;;
        --unban) UNBAN_IP="$2"; shift 2 ;;
        --status) SHOW_STATUS=true; shift ;;
        --logs) SHOW_LOGS=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if ! command -v fail2ban-client &>/dev/null; then
    echo "fail2ban not installed"
    exit 1
fi

echo "=== Fail2Ban Status ==="

if [[ "$SHOW_STATUS" == true ]]; then
    echo "--- Global Status ---"
    fail2ban-client status
    
    echo ""
    echo "--- Jail Status ---"
    JAILS=$(fail2ban-client status | grep "Jail list" | cut -d: -f2 | tr ',' '\n' | xargs)
    
    for jail in $JAILS; do
        jail=$(echo "$jail" | xargs)
        echo "Jail: $jail"
        fail2ban-client status "$jail"
        echo ""
    done
fi

if [[ -n "$JAIL" ]]; then
    echo "--- Jail: $JAIL ---"
    fail2ban-client status "$JAIL"
fi

if [[ -n "$UNBAN_IP" ]]; then
    echo "Unbanning IP: $UNBAN_IP"
    if [[ -n "$JAIL" ]]; then
        fail2ban-client set "$JAIL" unbanip "$UNBAN_IP"
    else
        # Unban from all jails
        JAILS=$(fail2ban-client status | grep "Jail list" | cut -d: -f2 | tr ',' '\n' | xargs)
        for jail in $JAILS; do
            jail=$(echo "$jail" | xargs)
            fail2ban-client set "$jail" unbanip "$UNBAN_IP" 2>/dev/null || true
        done
    fi
    echo "Unban completed"
fi

if [[ "$SHOW_LOGS" == true ]]; then
    echo "--- Recent Fail2Ban Logs ---"
    journalctl -u fail2ban -n 50 --no-pager
fi