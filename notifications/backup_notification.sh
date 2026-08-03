#!/bin/bash
# backup_notification.sh - Notify on backup success/failure
# Usage: ./backup_notification.sh --status success|failed --backup-name "name" [--details "details"] [--channel gotify|ntfy|discord]

set -euo pipefail

STATUS=""
BACKUP_NAME=""
DETAILS=""
CHANNEL="gotify"

while [[ $# -gt 0 ]]; do
    case $1 in
        --status) STATUS="$2"; shift 2 ;;
        --backup-name) BACKUP_NAME="$2"; shift 2 ;;
        --details) DETAILS="$2"; shift 2 ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$STATUS" || -z "$BACKUP_NAME" ]]; then
    echo "Usage: $0 --status success|failed --backup-name \"name\" [options]"
    exit 1
fi

HOSTNAME=$(hostname)

if [[ "$STATUS" == "success" ]]; then
    TITLE="✅ Backup Successful: $BACKUP_NAME"
    PRIORITY=3
    ICON="✅"
else
    TITLE="❌ Backup Failed: $BACKUP_NAME"
    PRIORITY=10
    ICON="❌"
fi

MESSAGE="$ICON **Backup $STATUS** - $HOSTNAME
**Backup**: $BACKUP_NAME
**Time**: $(date)"

if [[ -n "$DETAILS" ]]; then
    MESSAGE="$MESSAGE
**Details**: $DETAILS"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/01_notify.sh" ]]; then
    "$SCRIPT_DIR/01_notify.sh" --title "$TITLE" --message "$MESSAGE" --channel "$CHANNEL" --priority "$PRIORITY"
else
    echo "$MESSAGE"
fi