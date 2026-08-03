#!/bin/bash
# audit_sudoers.sh - Audit sudoers configuration
# Usage: ./audit_sudoers.sh [--file /etc/sudoers] [--check-nopasswd] [--check-wildcards]

set -euo pipefail

SUDOERS_FILE="/etc/sudoers"
CHECK_NOPASSWD=true
CHECK_WILDCARDS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --file) SUDOERS_FILE="$2"; shift 2 ;;
        --check-nopasswd) CHECK_NOPASSWD=true; shift ;;
        --check-wildcards) CHECK_WILDCARDS=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ ! -f "$SUDOERS_FILE" ]]; then
    echo "Sudoers file not found: $SUDOERS_FILE"
    exit 1
fi

echo "=== Sudoers Audit ==="
echo "File: $SUDOERS_FILE"

# Check syntax first
if ! visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
    echo "ERROR: Sudoers syntax check failed!"
    exit 1
fi
echo "Syntax: OK"

# Include sudoers.d
INCLUDE_FILES=("$SUDOERS_FILE")
if [[ -d /etc/sudoers.d ]]; then
    for f in /etc/sudoers.d/*; do
        [[ -f "$f" ]] && INCLUDE_FILES+=("$f")
    done
fi

ISSUES=0

for file in "${INCLUDE_FILES[@]}"; do
    echo ""
    echo "--- Checking $file ---"
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        if [[ "$CHECK_NOPASSWD" == true && "$line" =~ NOPASSWD ]]; then
            echo "  WARNING: NOPASSWD found: $line"
            ISSUES=$((ISSUES + 1))
        fi
        
        if [[ "$CHECK_WILDCARDS" == true && "$line" =~ ALL=\(ALL\)\s+ALL ]]; then
            if [[ ! "$line" =~ ^[[:space:]]*root|^# ]]; then
                echo "  WARNING: Wildcard ALL for non-root: $line"
                ISSUES=$((ISSUES + 1))
            fi
        fi
        
        # Check for dangerous commands
        if [[ "$line" =~ (su|bash|sh|vim|nano|less|more|awk|find|nc|netcat|nmap|ssh|scp|rsync)\s*$ ]]; then
            echo "  WARNING: Potentially dangerous command allowed: $line"
            ISSUES=$((ISSUES + 1))
        fi
        
    done < "$file"
done

echo ""
echo "=== Summary ==="
echo "Issues found: $ISSUES"

[[ $ISSUES -gt 0 ]] && exit 1 || exit 0