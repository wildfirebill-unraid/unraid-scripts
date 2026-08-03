#!/bin/bash
# network_tuning.sh - Apply network performance tuning
# Usage: ./network_tuning.sh [--apply] [--revert] [--interface eth0] [--profile high-throughput|low-latency]

set -euo pipefail

APPLY=false
REVERT=false
INTERFACE=""
PROFILE="high-throughput"

while [[ $# -gt 0 ]]; do
    case $1 in
        --apply) APPLY=true; shift ;;
        --revert) REVERT=true; shift ;;
        --interface) INTERFACE="$2"; shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ "$REVERT" == true ]]; then
    echo "=== Reverting Network Tuning ==="
    sysctl -p /etc/sysctl.d/99-network-tuning.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-network-tuning.conf
    echo "Reverted"
    exit 0
fi

if [[ -z "$INTERFACE" ]]; then
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
fi

echo "=== Network Tuning ==="
echo "Interface: $INTERFACE"
echo "Profile: $PROFILE"
[[ "$APPLY" == true ]] && echo "APPLY MODE" || echo "PREVIEW MODE"

SYSCTL_CONF="/etc/sysctl.d/99-network-tuning.conf"

cat > /tmp/network_tuning.conf <<EOF
# Network tuning for $PROFILE profile
# Generated: $(date)

# Increase TCP buffer sizes
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 65536

# TCP buffer tuning
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Increase backlog
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 65535

# TCP congestion control
net.ipv4.tcp_congestion_control = bbr

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Reduce latency
net.ipv4.tcp_low_latency = 1

# Disable TCP timestamps (saves 12 bytes per packet)
net.ipv4.tcp_timestamps = 0

# Enable TCP SACK
net.ipv4.tcp_sack = 1

# Enable window scaling
net.ipv4.tcp_window_scaling = 1

# Increase max connections
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000

# Reduce FIN timeout
net.ipv4.tcp_fin_timeout = 10

# Keepalive
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10

EOF

if [[ "$PROFILE" == "low-latency" ]]; then
    cat >> /tmp/network_tuning.conf <<EOF
# Low latency specific
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 0
net.ipv4.tcp_thin_linear_timeouts = 1
net.ipv4.tcp_thin_dupack = 1
EOF
fi

cat /tmp/network_tuning.conf

if [[ "$APPLY" == true ]]; then
    cp /tmp/network_tuning.conf "$SYSCTL_CONF"
    sysctl -p "$SYSCTL_CONF"
    
    # Interface specific tuning
    ethtool -K "$INTERFACE" tso on gso on gro on lro on rx on tx on 2>/dev/null || true
    ethtool -G "$INTERFACE" rx 4096 tx 4096 2>/dev/null || true
    
    echo "Applied network tuning"
else
    echo "Run with --apply to apply changes"
fi