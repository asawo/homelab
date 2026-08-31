# Homelab

Configuration files for my homelab services running on Proxmox VE 9.1.

## Network

| Host | DNS | Role |
|------|-----|------|
| pve | pve.lan | Proxmox hypervisor |
| pihole | pihole.lan | DNS + ad blocking (LXC 100) — being migrated to AdGuard |
| adguard | adguard.home | DNS + ad blocking, replacing Pi-hole (LXC 107) |
| immich | photos.home | Photo management (LXC 101) |
| copyparty | files.home | File server for DAS (LXC 102) |
| stirling-pdf | pdf.home | PDF tools (LXC 103) |
| sftpgo | bucket.home | SFTP/WebDAV file server (LXC 104) |
| filebrowser | nas.home | File browser (LXC 105) |
| leafwiki | wiki.home | Wiki (LXC 106) |

## Services

### Proxmox
- LXC container configs, network interfaces, and fstab
- Storage: `local` (dir) + `local-lvm` (lvmthin) + USB DAS (2x WD Red 1TB)
- Nightly borg backup from `/mnt/storage` to `/mnt/backup` at 3am
- Storage health check every 5 minutes (`proxmox/check-storage.sh`): detects the DAS mounts or a container's bind mount going stale (e.g. after the enclosure loses power), auto-fixes by remounting and/or rebooting the affected container, and alerts via [ntfy.sh](https://ntfy.sh) after 3 failed attempts instead of retrying forever
  - Reads `NTFY_TOPIC` from `/usr/local/etc/check-storage.env` on the host — `check-storage.env` is gitignored (the topic is unauthenticated, so it's a secret), see `check-storage.env.example` for the template

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
- Overlaps with SFTPGo and FileBrowser Quantum, but kept for the upload performance

### Stirling PDF (CT 103)
- Docker Compose running Stirling PDF for PDF manipulation tools
- File storage at `/mnt/storage/files/NAS/stirling-pdf` on the DAS

### SFTPGo (CT 104) — `not running`
- SFTP, WebDAV, and HTTP file server for the DAS
- Serves `/mnt/storage/files` with web admin UI on port 8080
- `.env` is gitignored (contains credentials) — see `.env.example` for template

### FileBrowser Quantum (CT 105)
- Web-based file browser for the DAS
- Serves `/mnt/storage/files` on port 8080

### LeafWiki (CT 106)
- Lightweight self-hosted wiki with Markdown stored on disk
- Web UI on port 8080
- `.env` is gitignored (contains JWT secret and admin password) — see `.env.example` for template

### AdGuard Home (CT 107)
- Docker Compose, DNS on port 53 (tcp+udp) and web UI on port 3000
- Replacing Pi-hole as the tailnet's DNS resolver (Tailscale Global nameserver) — see migration notes below
- `adguard/conf/AdGuardHome.yaml` is gitignored (contains admin password hash) — recreated via the setup wizard on first run

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
just push-adguard      # Push AdGuard Home docker-compose
just push-filebrowser  # Push FileBrowser configs and restart service
just push-leafwiki     # Push LeafWiki configs and restart service
just ssh [target]      # SSH into pve, immich, pihole, copyparty, stirling, sftpgo, filebrowser, leafwiki, or adguard
just logs [target]     # Tail logs (immich, pihole, copyparty, stirling, sftpgo, filebrowser, leafwiki, adguard, backup, storage-check)
just status            # Show container status
just check-storage     # Manually run the storage health check
just update-tailscale  # Upgrade Tailscale on all LXCs that have it installed
just restart-immich    # Restart the Immich docker stack
just restart-stirling  # Restart the Stirling PDF container
just restart-adguard   # Restart the AdGuard Home container
```

## Sensitive files

All `.env` files, secrets, keys, and credentials are excluded via `.gitignore`. Use `.env.example` files as templates.
