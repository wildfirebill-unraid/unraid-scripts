#!/bin/bash
# docker-cleanup.sh
# Clean up unused Docker images, containers, and volumes on Unraid
# Safe to run via User Scripts plugin

set -euo pipefail

LOG_FILE="/var/log/docker-cleanup.log"
KEEP_IMAGES=3        # Keep last N versions of each image
DRY_RUN=false

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --keep) KEEP_IMAGES="$2"; shift 2 ;;
        *) shift ;;
    esac
done

log "Starting Docker cleanup (dry-run: $DRY_RUN)"

# Clean stopped containers
log "Removing stopped containers..."
if [[ "$DRY_RUN" == "true" ]]; then
    docker container ls -aq --filter status=exited | tee -a "$LOG_FILE"
else
    docker container prune -f 2>&1 | tee -a "$LOG_FILE"
fi

# Clean unused networks
log "Removing unused networks..."
if [[ "$DRY_RUN" == "true" ]]; then
    docker network ls --filter type=custom -q | tee -a "$LOG_FILE"
else
    docker network prune -f 2>&1 | tee -a "$LOG_FILE"
fi

# Clean unused volumes (be careful!)
log "Removing unused volumes..."
if [[ "$DRY_RUN" == "true" ]]; then
    docker volume ls -qf dangling=true | tee -a "$LOG_FILE"
else
    docker volume prune -f 2>&1 | tee -a "$LOG_FILE"
fi

# Clean old image versions (keep latest N)
log "Cleaning old image versions (keeping $KEEP_IMAGES per repo)..."
images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | sort)

for img in $images; do
    repo=$(echo "$img" | cut -d: -f1)
    # Get all tags for this repo, sorted by creation date
    tags=$(docker images "$repo" --format "{{.Tag}} {{.CreatedAt}}" | sort -k2 -r | tail -n +$((KEEP_IMAGES + 1)) | awk '{print $1}')
    
    for tag in $tags; do
        if [[ "$tag" != "latest" ]]; then
            full_img="$repo:$tag"
            log "Would remove: $full_img"
            if [[ "$DRY_RUN" == "false" ]]; then
                docker rmi "$full_img" 2>&1 | tee -a "$LOG_FILE"
            fi
        fi
    done
done

log "Docker cleanup completed"