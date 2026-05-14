# Homelab

Configuration files for my homelab services running on Proxmox VE 9.1.

## Network

| Host | DNS | Role |
|------|-----|------|
| pve | pve.lan | Proxmox hypervisor |
| pihole | pihole.lan | DNS + ad blocking (LXC 100) |
| immich | photos.home | Photo management (LXC 101) |
| copyparty | files.home | File server for DAS (LXC 102) |
| stirling-pdf | pdf.home | PDF tools (LXC 103) |
| sftpgo | bucket.home | SFTP/WebDAV file server (LXC 104) |

## Services

### Proxmox
- LXC container configs, network interfaces, and fstab
- Storage: `local` (dir) + `local-lvm` (lvmthin) + USB DAS (2x WD Red 1TB)
- Nightly borg backup from `/mnt/storage` to `/mnt/backup` at 3am

### Pi-hole (CT 100)
- Pi-hole v6 with Cloudflare DNS upstream
- Adlist configuration tracked in `pihole/adlists.csv`
- `pihole.toml` is gitignored (contains password hash) — use `just pull` to fetch locally

### Immich (CT 101)
- Docker Compose with OpenVINO ML acceleration and GPU passthrough
- `.env` is gitignored (contains DB password) — see `.env.example` for template

### Copyparty (CT 102)
- Python file server for uploading/browsing files on the DAS
- Serves `/mnt/storage/files` on port 3923 with password auth, Tailscale enabled
- `.env` is gitignored (contains credentials) — see `.env.example` for template

### Stirling PDF (CT 103)
- Docker Compose running Stirling PDF for PDF manipulation tools
- File storage at `/mnt/storage/files/NAS/stirling-pdf` on the DAS

### SFTPGo (CT 104)
- SFTP, WebDAV, and HTTP file server for the DAS
- Serves `/mnt/storage/files` with web admin UI on port 8080
- `.env` is gitignored (contains credentials) — see `.env.example` for template

## Usage

Requires [just](https://github.com/casey/just).

```
just pull              # Pull all configs from hosts
just diff              # Show what differs between local and host
just push-pve          # Push Proxmox configs (network, fstab, backup, crontab)
just push-pihole       # Push Pi-hole config and restart FTL
just push-immich       # Push Immich configs to the host
just push-copyparty    # Push Copyparty configs and restart service
just push-stirling     # Push Stirling PDF docker-compose
just push-sftpgo       # Push SFTPGo configs and restart service
just ssh [target]      # SSH into pve, immich, pihole, copyparty, stirling, or sftpgo
just logs [target]     # Tail logs (immich, pihole, copyparty, stirling, sftpgo, backup)
just status            # Show container status
just restart-immich    # Restart the Immich docker stack
just restart-stirling  # Restart the Stirling PDF container
```

## Sensitive files

All `.env` files, secrets, keys, and credentials are excluded via `.gitignore`. Use `.env.example` files as templates.
