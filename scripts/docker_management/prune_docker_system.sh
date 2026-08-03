#!/bin/bash
# prune_docker_system.sh - Comprehensive Docker system cleanup
# Usage: ./prune_docker_system.sh [--all] [--volumes] [--networks] [--dry-run] [--force]

set -euo pipefail

ALL=false
VOLUMES=false
NETWORKS=false
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all) ALL=true; shift ;;
        --volumes) VOLUMES=true; shift ;;
        --networks) NETWORKS=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Docker System Prune ==="
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

# Calculate space before
SPACE_BEFORE=$(docker system df --format "{{.Size}}" | awk '{sum+=$1} END {print sum}')

if [[ "$ALL" == true || "$DRY_RUN" == true ]]; then
    echo "Pruning containers..."
    if [[ "$DRY_RUN" == false ]]; then
        docker container prune -f ${FORCE:+--filter "until=24h"}
    else
        docker container prune --dry-run
    fi
fi

if [[ "$ALL" == true || "$VOLUMES" == true || "$DRY_RUN" == true ]]; then
    echo "Pruning volumes..."
    if [[ "$DRY_RUN" == false ]]; then
        docker volume prune -f
    else
        docker volume prune --dry-run
    fi
fi

if [[ "$ALL" == true || "$NETWORKS" == true || "$DRY_RUN" == true ]]; then
    echo "Pruning networks..."
    if [[ "$DRY_RUN" == false ]]; then
        docker network prune -f
    else
        docker network prune --dry-run
    fi
fi

if [[ "$ALL" == true || "$DRY_RUN" == true ]]; then
    echo "Pruning images..."
    if [[ "$DRY_RUN" == false ]]; then
        docker image prune -a -f ${FORCE:+--filter "until=24h"}
    else
        docker image prune -a --dry-run
    fi
fi

# Build cache
echo "Pruning build cache..."
if [[ "$DRY_RUN" == false ]]; then
    docker builder prune -a -f
else
    docker builder prune -a --dry-run
fi

SPACE_AFTER=$(docker system df --format "{{.Size}}" | awk '{sum+=$1} END {print sum}')
SPACE_FREED=$((SPACE_BEFORE - SPACE_AFTER))

echo ""
echo "=== Prune Summary ==="
echo "Space before: $(numfmt --to=iec $SPACE_BEFORE)"
echo "Space after: $(numfmt --to=iec $SPACE_AFTER)"
echo "Space freed: $(numfmt --to=iec $SPACE_FREED)"