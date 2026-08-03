#!/bin/bash
# notify.sh - Unified notification sender for multiple channels
# Usage: ./notify.sh --title "Title" --message "Message" [--channel gotify|ntfy|discord|slack|email|pushover] [--priority N]

set -euo pipefail

TITLE=""
MESSAGE=""
CHANNEL="gotify"
PRIORITY=5

# Channel configs (set via environment variables)
GOTIFY_URL="${GOTIFY_URL:-}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
NTFY_TOPIC="${NTFY_TOPIC:-}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
EMAIL_TO="${EMAIL_TO:-}"
EMAIL_FROM="${EMAIL_FROM:-}"
PUSHOVER_TOKEN="${PUSHOVER_TOKEN:-}"
PUSHOVER_USER="${PUSHOVER_USER:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --title) TITLE="$2"; shift 2 ;;
        --message) MESSAGE="$2"; shift 2 ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        --priority) PRIORITY="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$TITLE" || -z "$MESSAGE" ]]; then
    echo "Usage: $0 --title \"Title\" --message \"Message\" [options]"
    exit 1
fi

send_gotify() {
    if [[ -z "$GOTIFY_URL" || -z "$GOTIFY_TOKEN" ]]; then
        echo "Gotify not configured"
        return 1
    fi
    curl -s -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"priority\":$PRIORITY}" >/dev/null
}

send_ntfy() {
    if [[ -z "$NTFY_TOPIC" ]]; then
        echo "ntfy topic not configured"
        return 1
    fi
    curl -s -X POST "https://ntfy.sh/$NTFY_TOPIC" \
        -H "Title: $TITLE" \
        -H "Priority: $PRIORITY" \
        -d "$MESSAGE" >/dev/null
}

send_discord() {
    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        echo "Discord webhook not configured"
        return 1
    fi
    PAYLOAD=$(jq -n --arg title "$TITLE" --arg desc "$MESSAGE" '{embeds: [{title: $title, description: $desc, color: 3447003}]}')
    curl -s -X POST "$DISCORD_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" >/dev/null
}

send_slack() {
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        echo "Slack webhook not configured"
        return 1
    fi
    PAYLOAD=$(jq -n --arg title "$TITLE" --arg text "$MESSAGE" '{attachments: [{title: $title, text: $text, color: "good"}]}')
    curl -s -X POST "$SLACK_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" >/dev/null
}

send_email() {
    if [[ -z "$EMAIL_TO" || -z "$EMAIL_FROM" ]]; then
        echo "Email not configured"
        return 1
    fi
    echo "$MESSAGE" | mail -s "$TITLE" -r "$EMAIL_FROM" "$EMAIL_TO"
}

send_pushover() {
    if [[ -z "$PUSHOVER_TOKEN" || -z "$PUSHOVER_USER" ]]; then
        echo "Pushover not configured"
        return 1
    fi
    curl -s -X POST "https://api.pushover.net/1/messages.json" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "token=$PUSHOVER_TOKEN&user=$PUSHOVER_USER&title=$TITLE&message=$MESSAGE&priority=$PRIORITY" >/dev/null
}

case $CHANNEL in
    gotify) send_gotify ;;
    ntfy) send_ntfy ;;
    discord) send_discord ;;
    slack) send_slack ;;
    email) send_email ;;
    pushover) send_pushover ;;
    all)
        send_gotify || true
        send_ntfy || true
        send_discord || true
        send_slack || true
        send_email || true
        send_pushover || true
        ;;
    *) echo "Unknown channel: $CHANNEL"; exit 1 ;;
esac

echo "Notification sent via $CHANNEL"