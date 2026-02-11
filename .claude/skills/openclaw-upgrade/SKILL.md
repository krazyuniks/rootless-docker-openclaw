---
name: openclaw-upgrade
description: Upgrade OpenClaw to a specific version or latest. Use when the user wants to update, upgrade, or reinstall OpenClaw. Handles git checkout, Docker image rebuild, and gateway restart.
---

# OpenClaw Upgrade Skill

Upgrade the OpenClaw installation to a specified version tag.

## Prerequisites

- Must run as the `openclaw` user (owns the repo and rootless Docker)
- If running as another user: `sudo -u openclaw -E claude` (preserves auth credentials)

## Arguments

- `$ARGUMENTS` — version tag (e.g. `2026.2.9` or `v2026.2.9`). If empty, upgrade to latest tag.

## Paths

| Path | Purpose |
|------|---------|
| `/home/openclaw/openclaw` | OpenClaw git repo |
| `/home/openclaw/.openclaw` | OpenClaw config/workspace |
| `/home/openclaw/rootless-openclaw` | This deployment repo |
| `/home/openclaw/rootless-openclaw/scripts/05-start.sh` | Gateway start script |
| `/home/openclaw/rootless-openclaw/.env` | API keys (BRAVE_API_KEY, etc.) |

## Workflow

### 1. Determine target version

```bash
# Fetch latest tags
git -C /home/openclaw/openclaw fetch --tags

# If no version specified, find the latest tag
git -C /home/openclaw/openclaw tag --sort=-v:refname | head -5

# Show current version
git -C /home/openclaw/openclaw describe --tags
```

Normalise the version: if user provides `2026.2.9`, prefix with `v` → `v2026.2.9`.

Verify the tag exists before proceeding:
```bash
git -C /home/openclaw/openclaw tag -l "v2026.2.9"
```

### 2. Check for running container

```bash
docker ps --filter name=openclaw-gateway --format '{{.Names}} {{.Image}} {{.Status}}'
```

If running, inform the user it will be stopped during the upgrade.

### 3. Checkout target version

```bash
git -C /home/openclaw/openclaw checkout v2026.2.9
```

### 4. Rebuild Docker image

```bash
docker build -t openclaw:local -f /home/openclaw/openclaw/Dockerfile /home/openclaw/openclaw
```

This takes a few minutes. Run with a longer timeout.

### 5. Restart gateway

```bash
/home/openclaw/rootless-openclaw/scripts/05-start.sh
```

### 6. Verify

```bash
docker ps --filter name=openclaw-gateway --format '{{.Names}} {{.Image}} {{.Status}}'
```

Report the upgrade result: previous version → new version.

## Rollback

If the upgrade fails, checkout the previous tag and rebuild:
```bash
git -C /home/openclaw/openclaw checkout <previous-tag>
docker build -t openclaw:local -f /home/openclaw/openclaw/Dockerfile /home/openclaw/openclaw
/home/openclaw/rootless-openclaw/scripts/05-start.sh
```

## Guidelines

- Always confirm the target version exists before checking out
- Show the user what version they're upgrading from and to
- The Docker build can take several minutes — use a longer timeout
- Do NOT run `docker-setup.sh` for upgrades (that runs onboarding). Only use it for fresh installs.
- The start script in `05-start.sh` handles stopping any existing container automatically
