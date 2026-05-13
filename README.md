# Homelab

Configuration files for my homelab services running on Proxmox VE 9.1.

## Network

| Host | IP | Role |
|------|------|------|
| pve | 192.168.11.61 | Proxmox hypervisor |
| pihole | 192.168.11.200 | DNS + ad blocking (LXC 100) |
| immich | 192.168.11.201 | Photo management (LXC 101) |

## Services

### Proxmox
- LXC container configs and network interfaces
- Storage: `local` (dir, 70GB) + `local-lvm` (lvmthin, 145GB)

### Pi-hole (CT 100)
- Pi-hole v6 (pihole.toml config)
- Upstream DNS: Cloudflare (1.1.1.1, 1.0.0.1)
- Local DNS: pihole.lan, pve.lan, photos.home

### Immich (CT 101)
- Docker Compose with OpenVINO ML acceleration
- GPU passthrough (/dev/dri) for transcoding
- Photos stored at /mnt/storage/immich on host

## Sensitive files

All `.env` files, secrets, keys, and credentials are excluded via `.gitignore`. Use `.env.example` files as templates.
