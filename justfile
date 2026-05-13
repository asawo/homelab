pve := "root@pve.lan"
pihole_ct := "100"
immich_ct := "101"

# List available commands
default:
    @just --list

# SSH into a host (e.g. `just ssh pve`, `just ssh immich`, `just ssh pihole`)
ssh target="pve":
    #!/usr/bin/env bash
    case "{{ target }}" in
        pve)    ssh {{ pve }} ;;
        immich) ssh -t {{ pve }} "pct enter {{ immich_ct }}" ;;
        pihole) ssh -t {{ pve }} "pct enter {{ pihole_ct }}" ;;
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
    ssh {{ pve }} "crontab -l" > proxmox/crontab
    ssh {{ pve }} "pct config 100" > proxmox/ct-100-pihole.conf
    ssh {{ pve }} "pct config {{ immich_ct }}" > proxmox/ct-101-immich.conf

    echo "Pulling Pi-hole configs..."
    ssh {{ pve }} "pct exec {{ pihole_ct }} -- cat /etc/pihole/pihole.toml" > pihole/pihole.toml

    echo "Pulling Immich configs..."
    ssh {{ pve }} "pct exec {{ immich_ct }} -- cat /opt/immich/docker-compose.yml" > immich/docker-compose.yml
    ssh {{ pve }} "pct exec {{ immich_ct }} -- cat /opt/immich/hwaccel.transcoding.yml" > immich/hwaccel.transcoding.yml
    ssh {{ pve }} "pct exec {{ immich_ct }} -- cat /opt/immich/hwaccel.ml.yml" > immich/hwaccel.ml.yml
    ssh {{ pve }} "pct exec {{ immich_ct }} -- cat /opt/immich/.env" > immich/.env

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
    echo "  crontab"
    cat proxmox/crontab | ssh {{ pve }} "crontab -"
    echo "Done. Network changes need: just ssh pve, then 'ifreload -a'"

# Restart Immich stack on the host
restart-immich:
    ssh {{ pve }} "pct exec {{ immich_ct }} -- bash -c 'cd /opt/immich && docker compose down && docker compose up -d'"

# Tail logs (e.g. `just logs immich`, `just logs pihole`, `just logs backup`)
logs target:
    #!/usr/bin/env bash
    case "{{ target }}" in
        immich) ssh {{ pve }} "pct exec {{ immich_ct }} -- docker compose -f /opt/immich/docker-compose.yml logs -f --tail 100" ;;
        pihole) ssh {{ pve }} "pct exec {{ pihole_ct }} -- tail -f /var/log/pihole/pihole.log" ;;
        backup) ssh {{ pve }} "tail -f /var/log/borg-backup.log" ;;
        *)      echo "Unknown target: {{ target }} (try: immich, pihole, backup)"; exit 1 ;;
    esac

# Show container status
status:
    @ssh {{ pve }} "pct list"
