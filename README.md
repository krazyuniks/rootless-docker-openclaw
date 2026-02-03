# Rootless OpenClaw Deployment

Deploy OpenClaw with rootless Docker, nftables firewall, and proper UID/GID mapping.

## Quick Start

```bash
# Clone and run installer
git clone https://github.com/krazyuniks/rootless-openclaw.git /tmp/rootless-openclaw
cd /tmp/rootless-openclaw
sudo ./install.sh
```

The installer will:
1. Create the `openclaw` user
2. Configure nftables firewall (with Docker-forward rules)
3. Install rootless Docker
4. Clone OpenClaw source and run setup
5. Start the gateway

## Full Directory Structure

After installation, the complete structure is:

```
/home/openclaw/
├── openclaw/                          # Cloned from upstream during install
│   ├── docker-compose.yml             # Docker compose config
│   ├── docker-setup.sh                # Official setup script
│   ├── Dockerfile                     # Container build
│   ├── dist/                          # Built application
│   ├── apps/                          # OpenClaw apps
│   ├── agents/                        # AI agents
│   └── ...
│
├── rootless-openclaw/                  # This deployment repo
│   ├── install.sh                     # Main installer (chains all scripts)
│   ├── README.md                      # This file
│   ├── .gitignore
│   └── configs/
│       ├── nftables.conf              # Firewall rules (Docker-aware)
│       ├── docker-daemon.json         # Docker DNS config
│       └── systemd-docker-override.conf  # Docker restarts after nftables
│   └── scripts/
│       ├── 01-user-setup.sh           # Create openclaw user
│       ├── 02-firewall.sh             # Install nftables
│       ├── 03-docker-rootless.sh      # Install rootless Docker
│       ├── 04-openclaw.sh             # Clone & setup OpenClaw
│       └── 05-start.sh                # Start gateway
│
├── .openclaw/                          # Runtime config (created by OpenClaw)
│   ├── openclaw.json                  # Gateway configuration
│   ├── workspace/                     # Agent workspace
│   ├── agents/                        # AI agent configs
│   ├── credentials/                   # API keys
│   ├── canvas/                        # Agent canvas
│   ├── cron/                          # Scheduled tasks
│   ├── telegram/                      # Telegram bot config
│   └── devices/                       # Paired devices
│
├── .config/
│   └── docker/
│       └── daemon.json                # Docker daemon config (DNS)
│
└── bin/                                # Rootless Docker binaries
    ├── docker
    ├── dockerd
    ├── containerd
    ├── runc
    └── ...
```

## What This Provides

| Feature | Description |
|---------|-------------|
| **Rootless Docker** | OpenClaw runs as non-root user with UID namespace remapping |
| **nftables firewall** | Properly configured to work with Docker (avoids `flush ruleset`) |
| **Systemd integration** | Docker restarts after nftables reloads |
| **UID mapping** | Files owned correctly for container access |
| **Automated install** | Single script handles entire setup |

## Quick Reference

```bash
# SSH tunnel (from local machine)
ssh -L 18789:127.0.0.1:18789 openclaw@<server>

# Dashboard URL
http://127.0.0.1:18789/?token=<token>

# Get token
sudo -u openclaw cat /home/openclaw/.openclaw/openclaw.json | jq -r '.gateway.auth.token'

# Start gateway
sudo -u openclaw docker run -d --rm -p 18789:18789 -v ~/.openclaw:/home/node/.openclaw --name openclaw-gateway openclaw:local node dist/index.js gateway --bind lan

# Stop gateway
sudo -u openclaw docker rm -f openclaw-gateway

# CLI commands (while gateway running)
sudo -u openclaw docker exec openclaw-gateway node dist/index.js devices list
sudo -u openclaw docker exec openclaw-gateway node dist/index.js pairing approve telegram <CODE>
```

## Common Operations

### Access Dashboard

From your local machine:

```bash
ssh -L 18789:127.0.0.1:18789 openclaw@<server>
```

Get the token:

```bash
sudo -u openclaw cat /home/openclaw/.openclaw/openclaw.json | jq -r '.gateway.auth.token'
```

Open: `http://127.0.0.1:18789/?token=<your-token>`

### View Logs

```bash
sudo -u openclaw docker logs -f openclaw-gateway
```

### Restart Gateway

```bash
cd /home/openclaw/rootless-openclaw
sudo ./scripts/05-start.sh
```

### Update OpenClaw

```bash
cd /home/openclaw/openclaw
sudo -u openclaw git pull
./docker-setup.sh
sudo ../rootless-openclaw/scripts/05-start.sh
```

## Firewall (nftables + Docker)

The server uses nftables alongside Docker's iptables-nft rules.

| Component | Table | Purpose |
|-----------|-------|---------|
| Base firewall | `inet filter` | SSH, HTTP/HTTPS, input filtering |
| Docker | `ip filter`, `ip nat` | Container networking, MASQUERADE |

### Critical: Docker Forwarding Rules

The `inet filter forward` chain must allow Docker traffic:

```nft
chain forward {
    type filter hook forward priority 0; policy drop;

    # Allow Docker container traffic
    iifname "docker*" accept
    iifname "br-*" accept
    oifname "docker*" accept
    oifname "br-*" accept

    # Allow established/related for return traffic
    ct state established,related accept
}
```

### Critical: Avoid `flush ruleset`

Using `flush ruleset` in nftables.conf wipes Docker's NAT rules, breaking container networking. Use table-specific flush instead:

```nft
# Only flush our table, not Docker's
flush table inet filter
```

### Fixing Broken Docker Networking

If containers lose internet connectivity after nftables changes:

```bash
# Test container connectivity
sudo -u openclaw docker run --rm alpine ping -c 2 8.8.8.8

# Check if MASQUERADE rules exist
sudo nft list table ip nat | grep -i masquerade

# If missing, restart Docker to recreate them
sudo systemctl restart docker
```

## Rootless Docker UID Mapping

Rootless Docker uses UID namespace remapping. The container runs as UID 1000, which maps to a different UID on the host.

Check your subuid base:
```bash
grep openclaw /etc/subuid
# Example output: openclaw:165536:65536
```

Calculate the host UID:
```
host_uid = subuid_base + container_uid - 1
host_uid = 165536 + 1000 - 1 = 166535
```

| Container UID | Host UID | Calculation |
|---------------|----------|-------------|
| 1000 (node) | Varies | `subuid_base + 1000 - 1` |

Files must be owned by the calculated host UID for the container to read/write them.

### Fix Permissions

If you get permission denied errors after editing config:

```bash
# Get subuid base
grep openclaw /etc/subuid | awk -F: '{print $2}'  # e.g., 165536

# Calculate and fix ownership
SUBUID_BASE=$(grep openclaw /etc/subuid | awk -F: '{print $2}')
CONTAINER_UID=$(($SUBUID_BASE + 1000 - 1))
sudo chown -R $CONTAINER_UID:$CONTAINER_UID /home/openclaw/.openclaw
```

### Debug Permissions

```bash
sudo -u openclaw docker run --rm -v /home/openclaw/.openclaw:/home/node/.openclaw openclaw:local sh -c "id && ls -la /home/node/.openclaw"
```

If directory shows `nobody:nogroup`, fix ownership using the calculation above.

## Troubleshooting

### Containers can't reach internet

```bash
# Test container connectivity
sudo -u openclaw docker run --rm alpine ping -c 2 8.8.8.8

# Check if nftables forward chain is blocking
sudo nft list chain inet filter forward

# Check if Docker's MASQUERADE rules exist
sudo nft list table ip nat | grep -i masquerade

# Restart Docker if missing
sudo systemctl restart docker
```

### Full Reset

If everything is broken:

```bash
# Stop and remove container
sudo -u openclaw docker rm -f openclaw-gateway

# Remove runtime config
sudo rm -rf /home/openclaw/.openclaw

# Re-run installer
cd /home/openclaw/rootless-openclaw
sudo ./install.sh
```

## Files Reference

| Location | Purpose | Owner |
|----------|---------|-------|
| `/home/openclaw/openclaw/` | OpenClaw source (upstream) | openclaw |
| `/home/openclaw/rootless-openclaw/` | This deployment repo | openclaw |
| `/home/openclaw/.openclaw/` | Runtime config and workspace | Mapped UID |
| `/home/openclaw/.openclaw/openclaw.json` | Gateway configuration | Mapped UID |

## Security Notes

- Firewall allows SSH (rate-limited), HTTP/HTTPS, and OpenClaw gateway port
- All other inbound traffic dropped
- Docker forward chain explicitly allows bridge interfaces
- Using `flush table inet filter` instead of `flush ruleset` to preserve Docker NAT
- OpenClaw runs as non-root user with UID namespace remapping

## Customization

To customize firewall rules, edit `configs/nftables.conf` before running `install.sh`. Common changes:

- Add additional allowed ports in the `input` chain
- Modify rate limiting rules
- Add custom logging rules

## Links

- [OpenClaw Docs](https://docs.openclaw.ai/)
- [Docker Install Guide](https://docs.openclaw.ai/install/docker)
