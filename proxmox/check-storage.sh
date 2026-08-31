#!/bin/bash
set -uo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

MOUNTS=(/mnt/storage /mnt/backup)

declare -A CT_PATHS=(
  [101]=/mnt/immich
  [102]=/mnt/files
  [103]=/mnt/files
  [104]=/mnt/files
  [105]=/mnt/files
)

NTFY_TOPIC="lechte-homelab-health-2026"
STATE_FILE="/var/lib/homelab-check.state"
MAX_ATTEMPTS=3
REMINDER_INTERVAL=86400

FAIL_COUNT=0
ESCALATED=0
LAST_REMINDER=0
# shellcheck disable=SC1090
[ -f "$STATE_FILE" ] && source "$STATE_FILE"

log() {
  echo "$(date '+%F %T') $*"
}

notify() {
  local message="$1" priority="${2:-default}"
  curl -s -H "Priority: $priority" -d "$message" "ntfy.sh/$NTFY_TOPIC" >/dev/null
}

save_state() {
  cat >"$STATE_FILE" <<EOF
FAIL_COUNT=$FAIL_COUNT
ESCALATED=$ESCALATED
LAST_REMINDER=$LAST_REMINDER
EOF
}

broken=0
attempted_fix=0

for m in "${MOUNTS[@]}"; do
  if ! mountpoint -q "$m"; then
    log "$m not mounted, running mount -a"
    mount -a
    attempted_fix=1
  fi
  if ! mountpoint -q "$m"; then
    log "$m still not mounted after mount -a"
    broken=1
  fi
done

for ct in "${!CT_PATHS[@]}"; do
  path="${CT_PATHS[$ct]}"
  if ! pct exec "$ct" -- stat "$path" >/dev/null 2>&1; then
    log "CT $ct: read check failed on $path"
    broken=1
    if [ "$ESCALATED" -eq 0 ]; then
      log "CT $ct: rebooting to refresh bind mount"
      pct reboot "$ct"
      attempted_fix=1
      sleep 15
      if pct exec "$ct" -- stat "$path" >/dev/null 2>&1; then
        log "CT $ct: recovered after reboot"
      else
        log "CT $ct: still failing after reboot"
      fi
    fi
  fi
done

if [ "$broken" -eq 0 ]; then
  if [ "$FAIL_COUNT" -gt 0 ] || [ "$ESCALATED" -eq 1 ]; then
    log "All checks passing again, sending recovered alert"
    notify "Homelab storage check: recovered, all mounts and containers healthy again."
  else
    log "All checks passing"
  fi
  FAIL_COUNT=0
  ESCALATED=0
  LAST_REMINDER=0
  save_state
  exit 0
fi

FAIL_COUNT=$((FAIL_COUNT + 1))
log "Check failed (attempt $FAIL_COUNT, fix attempted: $attempted_fix)"

if [ "$ESCALATED" -eq 1 ]; then
  now=$(date +%s)
  if [ $((now - LAST_REMINDER)) -ge "$REMINDER_INTERVAL" ]; then
    log "Still broken, sending daily reminder alert"
    notify "Homelab storage check: still broken, needs manual intervention." high
    LAST_REMINDER=$now
  fi
elif [ "$FAIL_COUNT" -ge "$MAX_ATTEMPTS" ]; then
  log "Reached $MAX_ATTEMPTS consecutive failures, escalating"
  notify "Homelab storage check: failed $MAX_ATTEMPTS checks in a row, giving up on auto-fix. Needs manual intervention." high
  ESCALATED=1
  LAST_REMINDER=$(date +%s)
fi

save_state
