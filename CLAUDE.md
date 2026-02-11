# Rootless OpenClaw Deployment

Automated deployment of [OpenClaw](https://github.com/openclaw/openclaw) using rootless Docker.

## Architecture

- **Dedicated user**: `openclaw` — owns all OpenClaw files and runs rootless Docker
- **OpenClaw repo**: `/home/openclaw/openclaw` (cloned from GitHub, checked out to a version tag)
- **Config/data**: `/home/openclaw/.openclaw/` (mounted into container at `/home/node/.openclaw`)
- **Deployment scripts**: `/home/openclaw/rootless-openclaw/scripts/`
- **Docker image**: `openclaw:local` (built from OpenClaw's Dockerfile)
- **Container name**: `openclaw-gateway`
- **Gateway port**: 18789

## Running Claude as the openclaw user

Since the openclaw user owns the repo and Docker daemon:

```bash
sudo -u openclaw -E claude
```

The `-E` flag preserves your environment (including Claude auth credentials from `~/.claude/.credentials.json`).

## Key scripts

| Script | Purpose |
|--------|---------|
| `scripts/01-user-setup.sh` | Create openclaw user with subuid/subgid |
| `scripts/03-docker-rootless.sh` | Install rootless Docker for openclaw user |
| `scripts/04-openclaw.sh` | Clone repo, create dirs, run onboarding |
| `scripts/05-start.sh` | Stop/start gateway container |
| `scripts/info.sh` | Show service status, token, and connection info |

## Upgrading

Use the `/openclaw-upgrade` skill or see `.claude/skills/openclaw-upgrade/SKILL.md`.

Quick manual upgrade:
```bash
git -C /home/openclaw/openclaw fetch --tags
git -C /home/openclaw/openclaw checkout v<VERSION>
docker build -t openclaw:local -f /home/openclaw/openclaw/Dockerfile /home/openclaw/openclaw
/home/openclaw/rootless-openclaw/scripts/05-start.sh
```
