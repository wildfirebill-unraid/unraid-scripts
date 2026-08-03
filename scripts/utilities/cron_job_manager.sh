#!/bin/bash
# cron_job_manager.sh - Manage cron jobs for Unraid
# Usage: ./cron_job_manager.sh [--list] [--add "schedule" "command" "name"] [--remove "name"] [--enable "name"] [--disable "name"]

set -euo pipefail

ACTION="list"
SCHEDULE=""
COMMAND=""
NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --list) ACTION="list"; shift ;;
        --add) ACTION="add"; SCHEDULE="$2"; COMMAND="$3"; NAME="$4"; shift 4 ;;
        --remove) ACTION="remove"; NAME="$2"; shift 2 ;;
        --enable) ACTION="enable"; NAME="$2"; shift 2 ;;
        --disable) ACTION="disable"; NAME="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

CRON_FILE="/etc/cron.d/unraid_custom"

case $ACTION in
    list)
        echo "=== Custom Cron Jobs ==="
        if [[ -f "$CRON_FILE" ]]; then
            grep -v '^#' "$CRON_FILE" | grep -v '^$' | while read -r line; do
                echo "  $line"
            done
        else
            echo "  No custom cron jobs"
        fi
        ;;
        
    add)
        if [[ -z "$SCHEDULE" || -z "$COMMAND" || -z "$NAME" ]]; then
            echo "Usage: $0 --add \"schedule\" \"command\" \"name\""
            exit 1
        fi
        
        mkdir -p "$(dirname "$CRON_FILE")"
        touch "$CRON_FILE"
        
        # Remove existing with same name
        sed -i "/# $NAME$/d" "$CRON_FILE"
        
        # Add new entry
        echo "$SCHEDULE root $COMMAND # $NAME" >> "$CRON_FILE"
        echo "Added cron job: $NAME"
        ;;
        
    remove)
        if [[ -z "$NAME" ]]; then
            echo "Usage: $0 --remove \"name\""
            exit 1
        fi
        
        if [[ -f "$CRON_FILE" ]]; then
            sed -i "/# $NAME$/d" "$CRON_FILE"
            echo "Removed cron job: $NAME"
        fi
        ;;
        
    enable)
        if [[ -z "$NAME" ]]; then
            echo "Usage: $0 --enable \"name\""
            exit 1
        fi
        
        if [[ -f "$CRON_FILE" ]]; then
            sed -i "s/^#\s*\(.*# $NAME$\)/\1/" "$CRON_FILE"
            echo "Enabled cron job: $NAME"
        fi
        ;;
        
    disable)
        if [[ -z "$NAME" ]]; then
            echo "Usage: $0 --disable \"name\""
            exit 1
        fi
        
        if [[ -f "$CRON_FILE" ]]; then
            sed -i "s/^\(.*# $NAME$\)/# \1/" "$CRON_FILE"
            echo "Disabled cron job: $NAME"
        fi
        ;;
esac