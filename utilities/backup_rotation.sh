#!/bin/bash
# backup_rotation.sh - Manage backup rotation policies
# Usage: ./backup_rotation.sh --path /path --policy daily:N,weekly:N,monthly:N,yearly:N [--dry-run]

set -euo pipefail

BACKUP_PATH=""
POLICY="daily:7,weekly:4,monthly:6,yearly:2"
DRY_RUN=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) BACKUP_PATH="$2"; shift 2 ;;
        --policy) POLICY="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --execute) DRY_RUN=false; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$BACKUP_PATH" ]]; then
    echo "Usage: $0 --path /path --policy \"daily:N,weekly:N,monthly:N,yearly:N\" [options]"
    exit 1
fi

if [[ ! -d "$BACKUP_PATH" ]]; then
    echo "Backup path not found: $BACKUP_PATH"
    exit 1
fi

echo "=== Backup Rotation ==="
echo "Path: $BACKUP_PATH"
echo "Policy: $POLICY"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

# Parse policy
declare -A KEEP=()
IFS=',' read -ra POLICIES <<< "$POLICY"
for p in "${POLICIES[@]}"; do
    IFS=':' read -r type count <<< "$p"
    KEEP["$type"]=$count
done

# Find all backups (assuming format: backup_YYYYMMDD_HHMMSS or similar)
BACKUPS=($(find "$BACKUP_PATH" -maxdepth 1 -type f -o -type d | grep -E "backup_[0-9]{8}_[0-9]{6}" | sort -r))

if [[ ${#BACKUPS[@]} -eq 0 ]]; then
    echo "No backups found matching pattern"
    exit 0
fi

echo "Found ${#BACKUPS[@]} backups"

# Categorize backups
declare -A CATEGORIZED=()

for backup in "${BACKUPS[@]}"; do
    BASENAME=$(basename "$backup")
    DATE_STR=$(echo "$BASENAME" | grep -oE "[0-9]{8}_[0-9]{6}" | head -1)
    
    if [[ -z "$DATE_STR" ]]; then
        continue
    fi
    
    YEAR=${DATE_STR:0:4}
    MONTH=${DATE_STR:4:2}
    DAY=${DATE_STR:6:2}
    HOUR=${DATE_STR:9:2}
    MIN=${DATE_STR:11:2}
    
    # Daily - keep latest N
    DAILY_KEY="$YEAR-$MONTH-$DAY"
    if [[ -z "${CATEGORIZED[daily,$DAILY_KEY]:-}" ]]; then
        CATEGORIZED["daily,$DAILY_KEY"]="$backup"
    fi
    
    # Weekly - keep latest N per week
    WEEK_NUM=$(date -d "$YEAR-$MONTH-$DAY" +%V 2>/dev/null || echo "0")
    WEEKLY_KEY="$YEAR-W$WEEK_NUM"
    if [[ -z "${CATEGORIZED[weekly,$WEEKLY_KEY]:-}" ]]; then
        CATEGORIZED["weekly,$WEEKLY_KEY"]="$backup"
    fi
    
    # Monthly - keep latest N per month
    MONTHLY_KEY="$YEAR-$MONTH"
    if [[ -z "${CATEGORIZED[monthly,$MONTHLY_KEY]:-}" ]]; then
        CATEGORIZED["monthly,$MONTHLY_KEY"]="$backup"
    fi
    
    # Yearly - keep latest N per year
    YEARLY_KEY="$YEAR"
    if [[ -z "${CATEGORIZED[yearly,$YEARLY_KEY]:-}" ]]; then
        CATEGORIZED["yearly,$YEARLY_KEY"]="$backup"
    fi
done

# Determine which to keep
declare -A TO_KEEP=()

for type in daily weekly monthly yearly; do
    COUNT=${KEEP[$type]:-0}
    if [[ $COUNT -gt 0 ]]; then
        KEYS=()
        for key in "${!CATEGORIZED[@]}"; do
            if [[ "$key" == "$type,"* ]]; then
                KEYS+=("$key")
            fi
        done
        
        # Sort by date (newest first)
        IFS=$'\n' SORTED=($(sort -r <<< "${KEYS[*]}"))
        unset IFS
        
        for ((i=0; i<${#SORTED[@]} && i<COUNT; i++)); do
            BACKUP="${CATEGORIZED[${SORTED[i]}]}"
            TO_KEEP["$BACKUP"]=1
        done
    fi
done

# Delete old backups
DELETED=0
for backup in "${BACKUPS[@]}"; do
    if [[ -z "${TO_KEEP[$backup]:-}" ]]; then
        echo "DELETE: $(basename "$backup")"
        if [[ "$DRY_RUN" == false ]]; then
            rm -rf "$backup"
        fi
        DELETED=$((DELETED + 1))
    else
        echo "KEEP:   $(basename "$backup")"
    fi
done

echo ""
echo "Deleted: $DELETED"
echo "Kept: ${#TO_KEEP[@]}"