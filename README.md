# Homelab

Configuration files for my homelab services running on Proxmox VE 9.1.

## Network

| Host | DNS | Role |
|------|-----|------|
| pve | pve.lan | Proxmox hypervisor |
| pihole | pihole.lan | DNS + ad blocking (LXC 100) |
| immich | photos.home | Photo management (LXC 101) |

## Services

### Proxmox
- LXC container configs and network interfaces
- Storage: `local` (dir) + `local-lvm` (lvmthin)

### Pi-hole (CT 100)
- Pi-hole v6 with Cloudflare DNS upstream
- Adlist configuration tracked in `pihole/adlists.csv`
- `pihole.toml` is gitignored (contains password hash) — use `just pull` to fetch locally

### Immich (CT 101)
- Docker Compose with OpenVINO ML acceleration and GPU passthrough
- `.env` is gitignored (contains DB password) — see `.env.example` for template

## Usage

Requires [just](https://github.com/casey/just).

```
just pull           # Pull all configs from hosts
just diff           # Show what differs between local and host
just push-immich    # Push Immich configs to the host
just push-pihole    # Push Pi-hole config and restart FTL
just push-network   # Push Proxmox network config
just ssh [target]   # SSH into pve, immich, or pihole
just status         # Show container status
just restart-immich # Restart the Immich docker stack
```

## Sensitive files

All `.env` files, secrets, keys, and credentials are excluded via `.gitignore`. Use `.env.example` files as templates.
