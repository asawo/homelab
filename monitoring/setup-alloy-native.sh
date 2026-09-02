#!/bin/bash
set -euo pipefail

# Run once on each non-Docker LXC that ships journald logs natively:
# Copyparty (102), FileBrowser (105), LeafWiki (106). NOT the host --
# see monitoring/alloy-native.alloy's comment for why.
#
# Installs Grafana Alloy as a standalone binary (no Docker, no apt repo --
# matches this repo's other native-systemd services) and wires up the
# systemd unit. Config itself is pushed separately via `just push-monitoring`.

useradd --system --no-create-home --gid systemd-journal alloy 2>/dev/null || true

command -v unzip >/dev/null || (apt-get update -qq && apt-get install -y unzip)

curl -fsSL -o /tmp/alloy.zip https://github.com/grafana/alloy/releases/latest/download/alloy-linux-amd64.zip
unzip -o /tmp/alloy.zip -d /tmp
install -m 0755 /tmp/alloy-linux-amd64 /usr/local/bin/alloy
rm -f /tmp/alloy.zip /tmp/alloy-linux-amd64

mkdir -p /opt/alloy
chown alloy:systemd-journal /opt/alloy

echo "Alloy binary installed. Next: 'just push-monitoring' to push the config"
echo "and service unit, then 'systemctl daemon-reload && systemctl enable --now alloy'."
