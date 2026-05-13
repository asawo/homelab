#!/bin/bash

# Stop Immich containers for a consistent backup
/usr/sbin/pct exec 101 -- docker compose -f /opt/immich/docker-compose.yml down

# Create backup with date-based name
borg create --compression zstd,3 \
  /mnt/backup/borg-repo::{now:%Y-%m-%d} \
  /mnt/storage

# Prune old backups: keep 7 daily, 4 weekly, 6 monthly
borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
  /mnt/backup/borg-repo

# Compact to free space
borg compact /mnt/backup/borg-repo

# Restart Immich
/usr/sbin/pct exec 101 -- docker compose -f /opt/immich/docker-compose.yml up -d
