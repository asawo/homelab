# Homelab

Configuration files for my homelab services running on Proxmox VE 9.1.

## Network

| Host | DNS | Role |
|------|-----|------|
| pve | pve.lan | Proxmox hypervisor |
| pihole | pihole.lan | DNS + ad blocking (LXC 100) — being migrated to AdGuard |
| adguard | adguard.home | DNS + ad blocking, replacing Pi-hole (LXC 107) |
| monitoring | monitoring.home | Metrics, logs, uptime, alerting (LXC 108) |
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
  - Reads `NTFY_TOPIC` from `/usr/local/etc/check-storage.env` on the host — `check-storage.env` is gitignored, see `check-storage.env.example` for the template
  - Its cron entry also pipes output through `systemd-cat -t check-storage`, so its log rides along on the same journal-upload pipe as everything else in `monitoring/` — its own ntfy alerting and auto-remediation are unchanged

### Pi-hole (CT 100)
- Pi-hole v6 with Cloudflare DNS upstream
- Adlist configuration tracked in `pihole/adlists.csv`
- `pihole.toml` is gitignored (contains password hash) — use `just pull` to fetch locally

### Immich (CT 101)
- Docker Compose with OpenVINO ML acceleration and GPU passthrough
- `.env` is gitignored (contains DB password) — see `.env.example` for template
- Built-in Prometheus metrics enabled (`IMMICH_TELEMETRY_INCLUDE=all`, ports 8081/8082 on the LAN, same trust model as every other exposed port here); cAdvisor + Alloy sidecars added for observability

### Copyparty (CT 102)
- Python file server for uploading/browsing files on the DAS
- Serves `/mnt/storage/files` on port 3923 with password auth, Tailscale enabled
- `.env` is gitignored (contains credentials) — see `.env.example` for template
- Overlaps with SFTPGo and FileBrowser Quantum, but kept for the upload performance
- Journald forwarded to the central Loki via `systemd-journal-upload` (no app-level metrics support)

### Stirling PDF (CT 103)
- Docker Compose running Stirling PDF for PDF manipulation tools
- File storage at `/mnt/storage/files/NAS/stirling-pdf` on the DAS
- cAdvisor + Alloy sidecars added for observability — its own `/actuator/prometheus` endpoint is Enterprise-license-gated, so this is container-stats-only

### SFTPGo (CT 104) — `not running`
- SFTP, WebDAV, and HTTP file server for the DAS
- Serves `/mnt/storage/files` with web admin UI on port 8080
- `.env` is gitignored (contains credentials) — see `.env.example` for template

### FileBrowser Quantum (CT 105)
- Web-based file browser for the DAS
- Serves `/mnt/storage/files` on port 8080
- Journald forwarded to the central Loki via `systemd-journal-upload` (no app-level metrics support)

### LeafWiki (CT 106)
- Lightweight self-hosted wiki with Markdown stored on disk
- Web UI on port 8080
- `.env` is gitignored (contains JWT secret and admin password) — see `.env.example` for template
- Journald forwarded to the central Loki via `systemd-journal-upload` (no app-level metrics support)

### AdGuard Home (CT 107)
- Docker Compose, DNS on port 53 (tcp+udp) and web UI on port 3000
- Replacing Pi-hole as the tailnet's DNS resolver (Tailscale Global nameserver) — see migration notes below
- `adguard/conf/AdGuardHome.yaml` is gitignored (contains admin password hash) — recreated via the setup wizard on first run
- cAdvisor + Alloy sidecars added for observability; DNS query/blocked/latency stats scraped by a dedicated exporter running centrally in `monitoring/` (AdGuard has no built-in Prometheus endpoint)

### Monitoring (CT 108)
- Docker Compose: Prometheus, Grafana, Loki, Alertmanager, `prometheus-pve-exporter` (agentless host + per-CT metrics via the Proxmox API), `blackbox_exporter` (HTTP uptime checks), an AdGuard metrics exporter, and a central Alloy instance that relays journald logs into Loki
- In scope: Immich, Copyparty, Stirling PDF, FileBrowser, LeafWiki, AdGuard, and the host itself. Pi-hole and SFTPGo are excluded (both being deprecated)
- Alerting goes to ntfy.sh via a webhook bridge, reusing the same `NTFY_TOPIC` convention as `proxmox/check-storage.env` — covers container/host-down, resource saturation, and failed HTTP checks. `check-storage.sh`'s own alerting and auto-remediation are separate and untouched
- Metrics retained 30 days, logs 14 days — disk isn't the constraint (plenty of free space on the DAS), host RAM is; sized deliberately lean (~4GB available on the host) with hard per-sidecar memory limits
- Grafana is internal only (Tailscale/LAN-only), same trust model as every other service here — no public exposure, no reverse proxy
- `.env` is gitignored (contains a Proxmox API token, Grafana admin password, and AdGuard admin credentials) — see `.env.example` for template
- See the file comments in `monitoring/docker-compose.yml` and `monitoring/alloy/central-relay.alloy` for why logs are shipped via a hybrid `systemd-journal-upload`/Alloy design rather than one Alloy instance per container

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
just push-monitoring   # Push monitoring stack + journal-upload config to CT 108, host, and native-systemd LXCs
just ssh [target]      # SSH into pve, immich, pihole, copyparty, stirling, sftpgo, filebrowser, leafwiki, adguard, or monitoring
just logs [target]     # Tail logs (immich, pihole, copyparty, stirling, sftpgo, filebrowser, leafwiki, adguard, backup, storage-check, monitoring)
just status            # Show container status
just check-storage     # Manually run the storage health check
just update-tailscale  # Upgrade Tailscale on all LXCs that have it installed
just restart-immich    # Restart the Immich docker stack
just restart-stirling  # Restart the Stirling PDF container
just restart-adguard   # Restart the AdGuard Home container
just restart-monitoring # Restart the monitoring docker stack
```

## Sensitive files

All `.env` files, secrets, keys, and credentials are excluded via `.gitignore`. Use `.env.example` files as templates.
