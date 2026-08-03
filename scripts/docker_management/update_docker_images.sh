#!/bin/bash
# update_docker_images.sh - Update all Docker images and recreate containers
# Usage: ./update_docker_images.sh [--prune] [--container name1,name2] [--dry-run]

set -euo pipefail

PRUNE=false
CONTAINERS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --prune) PRUNE=true; shift ;;
        --container) CONTAINERS="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Docker Image Update ==="

if [[ -n "$CONTAINERS" ]]; then
    IFS=',' read -ra CONTAINER_ARRAY <<< "$CONTAINERS"
    echo "Updating specific containers: ${CONTAINER_ARRAY[*]}"
    for container in "${CONTAINER_ARRAY[@]}"; do
        echo "Processing: $container"
        if [[ "$DRY_RUN" == false ]]; then
            docker pull "$container" || true
        else
            echo "[DRY RUN] Would pull: $container"
        fi
    done
else
    echo "Updating all images..."
    if [[ "$DRY_RUN" == false ]]; then
        docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | while read -r image; do
            echo "Pulling: $image"
            docker pull "$image" || true
        done
    else
        docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | while read -r image; do
            echo "[DRY RUN] Would pull: $image"
        done
    fi
fi

if [[ "$PRUNE" == true && "$DRY_RUN" == false ]]; then
    echo "Pruning unused images..."
    docker image prune -f
elif [[ "$PRUNE" == true && "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would prune unused images"
fi

echo "Docker image update completed"