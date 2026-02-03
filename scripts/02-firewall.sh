#!/bin/bash
#
# Install nftables firewall configuration
#

set -e

NFTABLES_SRC="$(dirname "$0")/../configs/nftables.conf"
NFTABLES_DST="/etc/nftables.conf"

echo "==> Installing nftables firewall"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Backup existing config
if [ -f "$NFTABLES_DST" ]; then
    cp "$NFTABLES_DST" "${NFTABLES_DST}.backup.$(date +%Y%m%d%H%M%S)"
    echo "✓ Backed up existing config"
fi

# Copy new config
cp "$NFTABLES_SRC" "$NFTABLES_DST"
echo "✓ Installed nftables.conf"

# Enable and start nftables
systemctl enable --now nftables
echo "✓ nftables enabled and started"

# Show rules
echo ""
echo "==> Current firewall rules:"
nft list ruleset

echo ""
echo "✓ Firewall setup complete"
