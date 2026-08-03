#!/bin/bash
# docker_performance_tune.sh - Tune Docker daemon for performance
# Usage: ./docker_performance_tune.sh [--apply] [--revert] [--config /etc/docker/daemon.json]

set -euo pipefail

APPLY=false
REVERT=false
CONFIG="/etc/docker/daemon.json"

while [[ $# -gt 0 ]]; do
    case $1 in
        --apply) APPLY=true; shift ;;
        --revert) REVERT=true; shift ;;
        --config) CONFIG="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ "$REVERT" == true ]]; then
    echo "=== Reverting Docker Configuration ==="
    if [[ -f "${CONFIG}.backup" ]]; then
        cp "${CONFIG}.backup" "$CONFIG"
        systemctl restart docker
        echo "Reverted"
    else
        echo "No backup found"
    fi
    exit 0
fi

echo "=== Docker Performance Tuning ==="
echo "Config: $CONFIG"
[[ "$APPLY" == true ]] && echo "APPLY MODE" || echo "PREVIEW MODE"

# Create optimized daemon.json
cat > /tmp/docker_daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "dns": ["1.1.1.1", "8.8.8.8"],
  "experimental": false,
  "metrics-addr": "127.0.0.1:9323",
  "features": {
    "buildkit": true
  },
  "live-restore": true,
  "userland-proxy": false,
  "default-shm-size": "1G"
}
EOF

cat /tmp/docker_daemon.json

if [[ "$APPLY" == true ]]; then
    # Backup existing
    [[ -f "$CONFIG" ]] && cp "$CONFIG" "${CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    cp /tmp/docker_daemon.json "$CONFIG"
    systemctl restart docker
    echo "Docker configuration applied and daemon restarted"
else
    echo "Run with --apply to apply changes"
fi