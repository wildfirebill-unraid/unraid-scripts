#!/bin/bash
# parity_notification.sh - Notify on parity check events
# Usage: ./parity_notification.sh --event start|complete|error|cancel [--details "details"] [--channel gotify|ntfy|discord]

set -euo pipefail

EVENT=""
DETAILS=""
CHANNEL="gotify"

while [[ $# -gt 0 ]]; do
    case $1 in
        --event) EVENT="$2"; shift 2 ;;
        --details) DETAILS="$2"; shift 2 ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$EVENT" ]]; then
    echo "Usage: $0 --event start|complete|error|cancel [options]"
    exit 1
fi

HOSTNAME=$(hostname)

case $EVENT in
    start)
        TITLE="🔄 Parity Check Started"
        PRIORITY=3
        MESSAGE="Parity check started on $HOSTNAME at $(date)"
        ;;
    complete)
        TITLE="✅ Parity Check Complete"
        PRIORITY=3
        MESSAGE="Parity check completed successfully on $HOSTNAME at $(date)"
        ;;
    error)
        TITLE="❌ Parity Check Error"
        PRIORITY=10
        MESSAGE="Parity check encountered an error on $HOSTNAME at $(date)"
        ;;
    cancel)
        TITLE="⏹️ Parity Check Cancelled"
        PRIORITY=5
        MESSAGE="Parity check was cancelled on $HOSTNAME at $(date)"
        ;;
    *)
        echo "Unknown event: $EVENT"
        exit 1
        ;;
esac

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