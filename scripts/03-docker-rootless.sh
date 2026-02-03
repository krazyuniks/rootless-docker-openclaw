#!/bin/bash
#
# Install rootless Docker for user
#

set -e

USER="${OPENCLAW_USER:-openclaw}"
DOCKER_DAEMON_SRC="$(dirname "$0")/../configs/docker-daemon.json"
DOCKER_DAEMON_DST="/home/$USER/.config/docker/daemon.json"
SYSTEMD_OVERRIDE_SRC="$(dirname "$0")/../configs/systemd-docker-override.conf"
SYSTEMD_OVERRIDE_DST="/etc/systemd/system/docker.service.d/after-nftables.conf"

echo "==> Installing rootless Docker for $USER"

# Install Docker (if not already installed)
if ! command -v docker &>/dev/null; then
    echo "==> Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    echo "✓ Docker installed"
else
    echo "✓ Docker already installed"
fi

# Configure rootless Docker for user
echo "==> Configuring rootless Docker..."
sudo -u "$USER" dockerd-rootless-setuptool.sh install
echo "✓ Rootless Docker configured"

# Create Docker daemon config
echo "==> Configuring Docker daemon..."
sudo -u "$USER" mkdir -p "$(dirname "$DOCKER_DAEMON_DST")"
cp "$DOCKER_DAEMON_SRC" "$DOCKER_DAEMON_DST"
sudo -u "$USER" systemctl --user restart docker
echo "✓ Docker daemon configured with DNS"

# Install systemd override (Docker restarts after nftables)
echo "==> Installing systemd override..."
sudo mkdir -p "$(dirname "$SYSTEMD_OVERRIDE_DST")"
cp "$SYSTEMD_OVERRIDE_SRC" "$SYSTEMD_OVERRIDE_DST"
sudo systemctl daemon-reload
echo "✓ Systemd override installed"

# Verify Docker is working
echo ""
echo "==> Verifying Docker..."
sudo -u "$USER" docker version
echo ""
echo "✓ Rootless Docker setup complete"
