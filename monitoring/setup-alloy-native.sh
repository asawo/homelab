#!/bin/bash
set -euo pipefail

# Run once on each non-Docker LXC that ships journald logs natively:
# Copyparty (102), FileBrowser (105), LeafWiki (106). NOT the host --
# see monitoring/alloy-native.alloy's comment for why.
#
# Installs Grafana Alloy as a standalone binary (no Docker, no apt repo --
# matches this repo's other native-systemd services) and wires up the
# systemd unit. Config itself is pushed separately via `just push-monitoring`.

# To upgrade: bump both of these together, from the release's own SHA256SUMS
# file (https://github.com/grafana/alloy/releases/download/<version>/SHA256SUMS)
# -- re-running this script is safe, it overwrites the binary in place.
ALLOY_VERSION="v1.19.2"
ALLOY_SHA256="3694ea4e1044b367e1c21ffe28117f209c5989fa5e604d000321809f871ab701"

useradd --system --no-create-home --gid systemd-journal alloy 2>/dev/null || true

command -v unzip >/dev/null || (apt-get update -qq && apt-get install -y unzip)

curl -fsSL -o /tmp/alloy.zip "https://github.com/grafana/alloy/releases/download/${ALLOY_VERSION}/alloy-linux-amd64.zip"
echo "${ALLOY_SHA256}  /tmp/alloy.zip" | sha256sum -c -
unzip -o /tmp/alloy.zip -d /tmp
install -m 0755 /tmp/alloy-linux-amd64 /usr/local/bin/alloy
rm -f /tmp/alloy.zip /tmp/alloy-linux-amd64

mkdir -p /opt/alloy
chown alloy:systemd-journal /opt/alloy

echo "Alloy binary installed. Next: 'just push-monitoring' to push the config"
echo "and service unit, then 'systemctl daemon-reload && systemctl enable --now alloy'."
