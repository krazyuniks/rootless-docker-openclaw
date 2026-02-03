#!/bin/bash
#
# Create openclaw user and configure for rootless Docker
#

set -e

USER="openclaw"
echo "==> Creating user: $USER"

# Create user if doesn't exist
if ! id "$USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$USER"
    sudo loginctl enable-linger "$USER"
    echo "✓ User $USER created"
else
    echo "✓ User $USER already exists"
fi

# Show subuid/subgid for reference
echo ""
echo "==> UID/GID mappings:"
grep "$USER" /etc/subuid /etc/subgid

echo ""
echo "✓ User setup complete"
