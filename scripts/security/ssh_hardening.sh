#!/bin/bash
# ssh_hardening.sh - Harden SSH configuration
# Usage: ./ssh_hardening.sh [--config /etc/ssh/sshd_config] [--backup] [--apply]

set -euo pipefail

CONFIG="/etc/ssh/sshd_config"
BACKUP=true
APPLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --config) CONFIG="$2"; shift 2 ;;
        --backup) BACKUP=true; shift ;;
        --no-backup) BACKUP=false; shift ;;
        --apply) APPLY=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ ! -f "$CONFIG" ]]; then
    echo "SSH config not found: $CONFIG"
    exit 1
fi

echo "=== SSH Hardening ==="
echo "Config: $CONFIG"
[[ "$APPLY" == true ]] && echo "APPLY MODE" || echo "CHECK MODE"

HARDENING_RULES=(
    "Port 22"
    "Protocol 2"
    "PermitRootLogin no"
    "PubkeyAuthentication yes"
    "PasswordAuthentication no"
    "PermitEmptyPasswords no"
    "ChallengeResponseAuthentication no"
    "UsePAM yes"
    "X11Forwarding no"
    "PrintMotd no"
    "ClientAliveInterval 300"
    "ClientAliveCountMax 2"
    "MaxAuthTries 3"
    "MaxSessions 2"
    "LoginGraceTime 30"
    "Banner /etc/issue.net"
    "AllowUsers root@192.168.1.0/24"
    "DenyUsers *"
)

if [[ "$BACKUP" == true && "$APPLY" == true ]]; then
    cp "$CONFIG" "${CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backup created"
fi

CHANGES=0

for rule in "${HARDENING_RULES[@]}"; do
    KEY=$(echo "$rule" | awk '{print $1}')
    VALUE=$(echo "$rule" | cut -d' ' -f2-)
    
    # Check current value
    CURRENT=$(grep -E "^#?\s*$KEY\s" "$CONFIG" | tail -1 | sed 's/^#*//' | xargs || echo "")
    
    if [[ -z "$CURRENT" ]]; then
        # Not present, would add
        if [[ "$APPLY" == true ]]; then
            echo "$rule" >> "$CONFIG"
            echo "Added: $rule"
            CHANGES=$((CHANGES + 1))
        else
            echo "MISSING: $rule"
            CHANGES=$((CHANGES + 1))
        fi
    elif [[ "$CURRENT" != "$rule" ]]; then
        # Different value
        if [[ "$APPLY" == true ]]; then
            sed -i "s|^#*\\s*$KEY.*|$rule|" "$CONFIG"
            echo "Updated: $rule"
            CHANGES=$((CHANGES + 1))
        else
            echo "MISMATCH: $KEY (current: $CURRENT, expected: $VALUE)"
            CHANGES=$((CHANGES + 1))
        fi
    else
        echo "OK: $rule"
    fi
done

if [[ "$APPLY" == true && $CHANGES -gt 0 ]]; then
    echo "Restarting SSH..."
    systemctl reload sshd
fi

echo "Total changes: $CHANGES"