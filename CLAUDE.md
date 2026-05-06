# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Jump host (跳板机) management via frp reverse proxy. Enables SSH access to servers behind restricted subnets through a public jump host.

## Architecture

```
User Device → Jump Host (frps, public IP) → Target Servers (frpc, each on a unique remote port)
```

- **Jump Host**: Runs `frps`, accepts connections on port 7000, exposes remote ports 22001-22050
- **Target Servers**: Each runs `frpc`, registers an SSH tunnel on a unique remote port
- **User Device**: Connects via SSH `ProxyJump` through the jump host

## Scripts

| Script | Purpose | Where to run |
|--------|---------|-------------|
| `scripts/deploy-jumphost.sh [--ip <IP>]` | Install & start frps on jump host | Jump host |
| `scripts/add-server.sh <name> [--port 22] [--remote N]` | Generate frpc config + install script for a target server | Local |
| `scripts/generate-ssh-config.sh [<user>] [<ssh-key-path>]` | Generate SSH config with ProxyJump entries | Local |

## Configuration

- `config/frps.toml` — Jump host frp server template. Variables: `bindPort`, `auth.token`, `allowPorts`
- `config/frpc.toml` — Target server frp client template. Uses `{{VAR}}` placeholders for `JUMPHOST_IP`, `TOKEN`, `SERVER_NAME`, `SSH_PORT`, `REMOTE_PORT`
- `config/servers.csv` — Server inventory: `name,local_ssh_port,remote_port,description`

## Workflow

1. `deploy-jumphost.sh` on the jump host → generates `output/jumphost-info.json`
2. For each target: `add-server.sh <name>` → generates `output/servers/<name>/` with frpc config and install script
3. `scp` the generated files to each target server, run `install-frpc.sh`
4. `generate-ssh-config.sh` → generates `output/ssh-config` for your local machine

## Key Details

- frp version: 0.61.1 (Linux amd64), downloaded from GitHub releases
- Remote port range: 22001-22050, auto-allocated from `servers.csv`
- Both frps and frpc run as systemd services with auto-restart
- Authentication uses a shared token generated during jump host deployment
- SSH ProxyJump approach means no extra ports exposed — all traffic through standard SSH
