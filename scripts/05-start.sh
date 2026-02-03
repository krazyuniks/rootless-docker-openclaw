#!/bin/bash
#
# Start OpenClaw gateway
#

set -e

USER="openclaw"
IMAGE_NAME="openclaw:local"
CONTAINER_NAME="openclaw-gateway"
PORT=18789

echo "==> Starting OpenClaw gateway"

# Stop existing container if running
if sudo -u "$USER" docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    echo "==> Stopping existing container..."
    sudo -u "$USER" docker rm -f "$CONTAINER_NAME"
fi

# Start gateway
echo "==> Starting gateway on port $PORT..."
sudo -u "$USER" docker run -d --rm \
    -p "$PORT:$PORT" \
    -v "/home/$USER/.openclaw:/home/node/.openclaw" \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME" \
    node dist/index.js gateway --bind lan

echo ""
echo "✓ Gateway started"
echo ""
echo "==> Get your auth token:"
echo "sudo cat /home/$USER/.openclaw/openclaw.json | jq -r '.gateway.auth.token'"
echo ""
echo "==> Access dashboard at:"
echo "http://127.0.0.1:$PORT/?token=<your-token>"
echo ""
echo "==> Or create SSH tunnel from local machine:"
echo "ssh -L $PORT:127.0.0.1:$PORT $USER@<server>"
