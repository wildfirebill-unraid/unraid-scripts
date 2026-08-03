#!/bin/bash
# cleanup_old_kernels.sh - Remove old kernel packages to free space
# Usage: ./cleanup_old_kernels.sh [--keep N] [--dry-run]

set -euo pipefail

KEEP=3
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep) KEEP="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Kernel Cleanup ==="
echo "Keeping latest $KEEP kernels"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE"

CURRENT_KERNEL=$(uname -r)
echo "Current kernel: $CURRENT_KERNEL"

KERNELS=($(ls -1t /boot/vmlinuz-* 2>/dev/null | head -n "$KEEP" | xargs -n1 basename | sed 's/vmlinuz-//'))

echo "Kernels to keep:"
for k in "${KERNELS[@]}"; do
    echo "  - $k"
done

ALL_KERNELS=($(ls -1 /boot/vmlinuz-* 2>/dev/null | xargs -n1 basename | sed 's/vmlinuz-//'))

for kernel in "${ALL_KERNELS[@]}"; do
    if [[ " ${KERNELS[@]} " =~ " ${kernel} " ]]; then
        continue
    fi
    
    if [[ "$kernel" == "$CURRENT_KERNEL" ]]; then
        echo "Skipping current kernel: $kernel"
        continue
    fi
    
    echo "Removing kernel: $kernel"
    if [[ "$DRY_RUN" == false ]]; then
        rm -f "/boot/vmlinuz-$kernel" "/boot/initrd-$kernel" "/boot/System.map-$kernel" "/boot/config-$kernel"
        rm -rf "/lib/modules/$kernel"
    fi
done

echo "Kernel cleanup completed"