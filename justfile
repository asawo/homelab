pve := "root@pve.lan"
pihole_ct := "100"
immich_ct := "101"
copyparty_ct := "102"
stirling_ct := "103"
sftpgo_ct := "104"
filebrowser_ct := "105"
leafwiki_ct := "106"

# List available commands
default:
    @just --list

# SSH into a host (e.g. `just ssh pve`, `just ssh immich`, `just ssh pihole`)
ssh target="pve":
    #!/usr/bin/env bash
    case "{{ target }}" in
        pve)      ssh {{ pve }} ;;
        immich)   ssh -t {{ pve }} "pct enter {{ immich_ct }}" ;;
        pihole)   ssh -t {{ pve }} "pct enter {{ pihole_ct }}" ;;
        copyparty) ssh -t {{ pve }} "pct enter {{ copyparty_ct }}" ;;
        stirling)  ssh -t {{ pve }} "pct enter {{ stirling_ct }}" ;;
        sftpgo)   ssh -t {{ pve }} "pct enter {{ sftpgo_ct }}" ;;
        filebrowser) ssh -t {{ pve }} "pct enter {{ filebrowser_ct }}" ;;
        leafwiki) ssh -t {{ pve }} "pct enter {{ leafwiki_ct }}" ;;
        *)      echo "Unknown target: {{ target }}"; exit 1 ;;
    esac

# Show what differs between local and host
diff:
    #!/usr/bin/env bash
    set -euo pipefail
    changed=0
    check_diff() {
        local label="$1" local_file="$2" remote_cmd="$3"
        result=$(diff --color=always -u "$local_file" <(ssh {{ pve }} "$remote_cmd") 2>/dev/null) || true
        if [ -n "$result" ]; then
            echo "  $label"
            echo "$result" | tail -n +3
            echo ""
            changed=1
        fi
    }

    echo "Proxmox"
    check_diff "network.interfaces" proxmox/network.interfaces "cat /etc/network/interfaces"
    check_diff "fstab" proxmox/fstab "cat /etc/fstab"
    check_diff "borg-backup.sh" proxmox/borg-backup.sh "cat /usr/local/bin/borg-backup.sh"
    check_diff "check-storage.sh" proxmox/check-storage.sh "cat /usr/local/bin/check-storage.sh"
    check_diff "crontab" proxmox/crontab "crontab -l"

    echo "Pi-hole"
    check_diff "pihole.toml" pihole/pihole.toml "pct exec {{ pihole_ct }} -- cat /etc/pihole/pihole.toml"

    echo "Immich"
    for f in docker-compose.yml hwaccel.transcoding.yml hwaccel.ml.yml; do
        check_diff "$f" "immich/$f" "pct exec {{ immich_ct }} -- cat /opt/immich/$f"
    done
    if [ -f immich/.env ]; then
        check_diff ".env" immich/.env "pct exec {{ immich_ct }} -- cat /opt/immich/.env"
    fi

    echo "Copyparty"
    check_diff "copyparty.service" copyparty/copyparty.service "pct exec {{ copyparty_ct }} -- cat /etc/systemd/system/copyparty.service"
    if [ -f copyparty/.env ]; then
        check_diff ".env" copyparty/.env "pct exec {{ copyparty_ct }} -- cat /opt/copyparty/.env"
    fi

    echo "Stirling PDF"
    check_diff "docker-compose.yml" "stirling-pdf/docker-compose.yml" "pct exec {{ stirling_ct }} -- cat /opt/stirling-pdf/docker-compose.yml"

    # SFTPGo (CT 104) is currently not running
    # echo "SFTPGo"
    # if [ -f sftpgo/.env ]; then
    #     check_diff ".env" sftpgo/.env "pct exec {{ sftpgo_ct }} -- cat /opt/sftpgo/.env"
    # fi

    echo "FileBrowser"
    check_diff "config.yaml" filebrowser/config.yaml "pct exec {{ filebrowser_ct }} -- cat /opt/filebrowser/config.yaml"
    check_diff "filebrowser.service" filebrowser/filebrowser.service "pct exec {{ filebrowser_ct }} -- cat /etc/systemd/system/filebrowser.service"

    echo "LeafWiki"
    check_diff "leafwiki.service" leafwiki/leafwiki.service "pct exec {{ leafwiki_ct }} -- cat /etc/systemd/system/leafwiki.service"
    if [ -f leafwiki/.env ]; then
        check_diff ".env" leafwiki/.env "pct exec {{ leafwiki_ct }} -- cat /etc/leafwiki/.env"
    fi

    if [ "$changed" -eq 0 ]; then
        echo ""
        echo "Everything in sync."
    fi

# Pull all configs from the hosts into the local repo
pull:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pulling Proxmox configs..."
    ssh {{ pve }} "cat /etc/network/interfaces" > proxmox/network.interfaces
    ssh {{ pve }} "cat /etc/fstab" > proxmox/fstab
    ssh {{ pve }} "cat /usr/local/bin/borg-backup.sh" > proxmox/borg-backup.sh
    ssh {{ pve }} "cat /usr/local/bin/check-storage.sh" > proxmox/check-storage.sh
    ssh {{ pve }} "crontab -l" > proxmox/crontab
    ssh {{ pve }} "pct config 100" > proxmox/ct-100-pihole.conf
    ssh {{ pve }} "pct config {{ immich_ct }}" > proxmox/ct-101-immich.conf

    ssh {{ pve }} "pct config {{ copyparty_ct }}" > proxmox/ct-102-copyparty.conf
    ssh {{ pve }} "pct config {{ stirling_ct }}" > proxmox/ct-103-stirling.conf
    ssh {{ pve }} "pct config {{ sftpgo_ct }}" > proxmox/ct-104-sftpgo.conf
    ssh {{ pve }} "pct config {{ filebrowser_ct }}" > proxmox/ct-105-filebrowser.conf
    ssh {{ pve }} "pct config {{ leafwiki_ct }}" > proxmox/ct-106-leafwiki.conf

    echo "Pulling Pi-hole configs..."
    ssh {{ pve }} "pct exec {{ pihole_ct }} -- cat /etc/pihole/pihole.toml" > pihole/pihole.toml

    echo "Pulling Immich configs..."
    ssh {{ pve }} "pct exec {{ immich_ct }} -- cat /opt/immich/docker-compose.yml" > immich/docker-compose.yml
    ssh {{ pve }} "pct exec {{ immich_ct }} -- cat /opt/immich/hwaccel.transcoding.yml" > immich/hwaccel.transcoding.yml
    ssh {{ pve }} "pct exec {{ immich_ct }} -- cat /opt/immich/hwaccel.ml.yml" > immich/hwaccel.ml.yml
    ssh {{ pve }} "pct exec {{ immich_ct }} -- cat /opt/immich/.env" > immich/.env

    echo "Pulling Copyparty configs..."
    ssh {{ pve }} "pct exec {{ copyparty_ct }} -- cat /etc/systemd/system/copyparty.service" > copyparty/copyparty.service
    ssh {{ pve }} "pct exec {{ copyparty_ct }} -- cat /opt/copyparty/.env" > copyparty/.env

    echo "Pulling Stirling PDF configs..."
    ssh {{ pve }} "pct exec {{ stirling_ct }} -- cat /opt/stirling-pdf/docker-compose.yml" > stirling-pdf/docker-compose.yml

    # SFTPGo (CT 104) is currently not running
    # echo "Pulling SFTPGo configs..."
    # ssh {{ pve }} "pct exec {{ sftpgo_ct }} -- cat /opt/sftpgo/.env" > sftpgo/.env

    echo "Pulling FileBrowser configs..."
    ssh {{ pve }} "pct exec {{ filebrowser_ct }} -- cat /opt/filebrowser/config.yaml" > filebrowser/config.yaml
    ssh {{ pve }} "pct exec {{ filebrowser_ct }} -- cat /etc/systemd/system/filebrowser.service" > filebrowser/filebrowser.service

    echo "Pulling LeafWiki configs..."
    ssh {{ pve }} "pct exec {{ leafwiki_ct }} -- cat /etc/systemd/system/leafwiki.service" > leafwiki/leafwiki.service
    ssh {{ pve }} "pct exec {{ leafwiki_ct }} -- cat /etc/leafwiki/.env" > leafwiki/.env

    echo "Done. Run 'git diff' to see what changed."

# Push Immich configs to the host
push-immich:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pushing Immich configs..."
    for f in docker-compose.yml hwaccel.transcoding.yml hwaccel.ml.yml; do
        echo "  $f"
        cat "immich/$f" | ssh {{ pve }} "pct exec {{ immich_ct }} -- tee /opt/immich/$f > /dev/null"
    done
    if [ -f immich/.env ]; then
        echo "  .env"
        cat immich/.env | ssh {{ pve }} "pct exec {{ immich_ct }} -- tee /opt/immich/.env > /dev/null"
    fi
    echo "Done. Restart with: just restart-immich"

# Push Pi-hole config to the host
push-pihole:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pushing pihole.toml..."
    cat pihole/pihole.toml | ssh {{ pve }} "pct exec {{ pihole_ct }} -- tee /etc/pihole/pihole.toml > /dev/null"
    echo "Restarting pihole-FTL..."
    ssh {{ pve }} "pct exec {{ pihole_ct }} -- systemctl restart pihole-FTL"
    echo "Done."

# Push Proxmox configs to the host
push-pve:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pushing Proxmox configs..."
    echo "  network.interfaces"
    cat proxmox/network.interfaces | ssh {{ pve }} "tee /etc/network/interfaces > /dev/null"
    echo "  fstab"
    cat proxmox/fstab | ssh {{ pve }} "tee /etc/fstab > /dev/null"
    echo "  borg-backup.sh"
    cat proxmox/borg-backup.sh | ssh {{ pve }} "tee /usr/local/bin/borg-backup.sh > /dev/null && chmod +x /usr/local/bin/borg-backup.sh"
    echo "  check-storage.sh"
    cat proxmox/check-storage.sh | ssh {{ pve }} "tee /usr/local/bin/check-storage.sh > /dev/null && chmod +x /usr/local/bin/check-storage.sh"
    echo "  crontab"
    cat proxmox/crontab | ssh {{ pve }} "crontab -"
    echo "Done. Network changes need: just ssh pve, then 'ifreload -a'"

# Push Copyparty configs to the host
push-copyparty:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pushing Copyparty configs..."
    echo "  copyparty.service"
    cat copyparty/copyparty.service | ssh {{ pve }} "pct exec {{ copyparty_ct }} -- tee /etc/systemd/system/copyparty.service > /dev/null"
    if [ -f copyparty/.env ]; then
        echo "  .env"
        cat copyparty/.env | ssh {{ pve }} "pct exec {{ copyparty_ct }} -- tee /opt/copyparty/.env > /dev/null"
    fi
    echo "Restarting copyparty..."
    ssh {{ pve }} "pct exec {{ copyparty_ct }} -- bash -c 'systemctl daemon-reload && systemctl restart copyparty'"
    echo "Done."

# Push Stirling PDF configs to the host
push-stirling:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pushing Stirling PDF configs..."
    echo "  docker-compose.yml"
    cat stirling-pdf/docker-compose.yml | ssh {{ pve }} "pct exec {{ stirling_ct }} -- tee /opt/stirling-pdf/docker-compose.yml > /dev/null"
    echo "Done. Restart with: just restart-stirling"

# Push SFTPGo configs to the host (currently not running)
# push-sftpgo:
#     #!/usr/bin/env bash
#     set -euo pipefail
#     echo "Pushing SFTPGo configs..."
#     if [ -f sftpgo/.env ]; then
#         echo "  .env"
#         cat sftpgo/.env | ssh {{ pve }} "pct exec {{ sftpgo_ct }} -- tee /opt/sftpgo/.env > /dev/null"
#     fi
#     echo "Restarting sftpgo..."
#     ssh {{ pve }} "pct exec {{ sftpgo_ct }} -- systemctl restart sftpgo"
#     echo "Done."

# Push FileBrowser configs to the host
push-filebrowser:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pushing FileBrowser configs..."
    echo "  config.yaml"
    cat filebrowser/config.yaml | ssh {{ pve }} "pct exec {{ filebrowser_ct }} -- tee /opt/filebrowser/config.yaml > /dev/null"
    echo "  filebrowser.service"
    cat filebrowser/filebrowser.service | ssh {{ pve }} "pct exec {{ filebrowser_ct }} -- tee /etc/systemd/system/filebrowser.service > /dev/null"
    echo "Restarting filebrowser..."
    ssh {{ pve }} "pct exec {{ filebrowser_ct }} -- bash -c 'systemctl daemon-reload && systemctl restart filebrowser'"
    echo "Done."

# Push LeafWiki configs to the host
push-leafwiki:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pushing LeafWiki configs..."
    echo "  leafwiki.service"
    cat leafwiki/leafwiki.service | ssh {{ pve }} "pct exec {{ leafwiki_ct }} -- tee /etc/systemd/system/leafwiki.service > /dev/null"
    if [ -f leafwiki/.env ]; then
        echo "  .env"
        cat leafwiki/.env | ssh {{ pve }} "pct exec {{ leafwiki_ct }} -- tee /etc/leafwiki/.env > /dev/null"
    fi
    echo "Restarting leafwiki..."
    ssh {{ pve }} "pct exec {{ leafwiki_ct }} -- bash -c 'systemctl daemon-reload && systemctl restart leafwiki'"
    echo "Done."

# Restart Immich stack on the host
restart-immich:
    ssh {{ pve }} "pct exec {{ immich_ct }} -- bash -c 'cd /opt/immich && docker compose down && docker compose up -d'"

# Restart Stirling PDF on the host
restart-stirling:
    ssh {{ pve }} "pct exec {{ stirling_ct }} -- bash -c 'cd /opt/stirling-pdf && docker compose down && docker compose up -d'"

# Tail logs (e.g. `just logs immich`, `just logs pihole`, `just logs backup`)
logs target="pihole":
    #!/usr/bin/env bash
    case "{{ target }}" in
        immich)    ssh {{ pve }} "pct exec {{ immich_ct }} -- docker compose -f /opt/immich/docker-compose.yml logs -f --tail 100" ;;
        pihole)    ssh {{ pve }} "pct exec {{ pihole_ct }} -- tail -f /var/log/pihole/pihole.log" ;;
        copyparty) ssh {{ pve }} "pct exec {{ copyparty_ct }} -- journalctl -u copyparty -f" ;;
        stirling)  ssh {{ pve }} "pct exec {{ stirling_ct }} -- docker compose -f /opt/stirling-pdf/docker-compose.yml logs -f --tail 100" ;;
        sftpgo)    ssh {{ pve }} "pct exec {{ sftpgo_ct }} -- journalctl -u sftpgo -f" ;;
        filebrowser) ssh {{ pve }} "pct exec {{ filebrowser_ct }} -- journalctl -u filebrowser -f" ;;
        leafwiki)  ssh {{ pve }} "pct exec {{ leafwiki_ct }} -- journalctl -u leafwiki -f" ;;
        backup)    ssh {{ pve }} "tail -f /var/log/borg-backup.log" ;;
        storage-check) ssh {{ pve }} "tail -f /var/log/storage-check.log" ;;
        *)         echo "Unknown target: {{ target }} (try: immich, pihole, copyparty, stirling, sftpgo, filebrowser, leafwiki, backup, storage-check)"; exit 1 ;;
    esac

# Show container status
status:
    @ssh {{ pve }} "pct list"

# Manually run the storage health check (normally runs every 5 min via cron)
check-storage:
    ssh {{ pve }} "/usr/local/bin/check-storage.sh"

# Update Tailscale on all LXCs that have it installed
update-tailscale:
    #!/usr/bin/env bash
    set -e
    for ct in 100 101 102 103 105 106; do
        echo "=== CT $ct ==="
        ssh {{ pve }} "pct exec $ct -- bash -c 'apt-get update -qq && apt-get install --only-upgrade -y tailscale'"
    done
    echo "Done. Current versions:"
    for ct in 100 101 102 103 105 106; do
        echo -n "CT $ct: "
        ssh {{ pve }} "pct exec $ct -- tailscale version | head -1"
    done
