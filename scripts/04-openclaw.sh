#!/bin/bash
#
# Clone and setup OpenClaw
#

set -e

USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_DIR="/home/$USER/openclaw"
OPENCLAW_REPO="https://github.com/openclaw/openclaw.git"

echo "==> Setting up OpenClaw"

# Clone OpenClaw if doesn't exist
if [ ! -d "$OPENCLAW_DIR" ]; then
    echo "==> Cloning OpenClaw..."
    sudo -u "$USER" git clone "$OPENCLAW_REPO" "$OPENCLAW_DIR"
    echo "✓ OpenClaw cloned"
else
    echo "✓ OpenClaw already exists, pulling latest..."
    sudo -u "$USER" git -C "$OPENCLAW_DIR" pull
fi

cd "$OPENCLAW_DIR"

# Create directory structure with correct ownership
echo "==> Creating workspace directories..."
for dir in workspace agents/main/agent credentials identity canvas cron telegram devices; do
    sudo -u "$USER" mkdir -p ".openclaw/$dir"
done

# Fix ownership for container (container UID 1000 → host UID)
# Note: The -1 is because container UID 0 maps to the host user's UID,
# and container UID 1+ maps to the subuid range. So container UID 1000
# maps to subuid_base + 999, not subuid_base + 1000.
SUBUID_BASE=$(grep "$USER" /etc/subuid | awk -F: '{print $2}')
CONTAINER_UID=$(($SUBUID_BASE + 1000 - 1))
echo "==> Fixing ownership for container UID mapping (UID $CONTAINER_UID)..."
chown -R "$CONTAINER_UID:$CONTAINER_UID" ".openclaw"

# Grant container traverse permission on home directory
echo "==> Granting container traverse permission on /home/$USER..."
setfacl -m "u:$CONTAINER_UID:x" "/home/$USER"
echo "✓ Workspace configured"

# Run OpenClaw setup
echo ""
echo "==> Running OpenClaw setup..."
echo "This will build the Docker image and run onboarding."
echo "Have your AI provider API key and Telegram bot token ready."
echo ""
sudo -u "$USER" ./docker-setup.sh

echo ""
echo "✓ OpenClaw setup complete"
