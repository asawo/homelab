#!/bin/bash
set -euo pipefail

# Run inside CT 106 after container creation
# Downloads LeafWiki binary from GitHub releases and enables the systemd service

apt-get update && apt-get install -y curl

LATEST=$(curl -sL https://api.github.com/repos/perber/leafwiki/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
curl -fsSL "https://github.com/perber/leafwiki/releases/download/${LATEST}/leafwiki-${LATEST}-linux-amd64" -o /usr/local/bin/leafwiki
chmod +x /usr/local/bin/leafwiki

useradd -r -s /bin/false leafwiki

mkdir -p /opt/leafwiki/data /etc/leafwiki
chown -R leafwiki:leafwiki /opt/leafwiki

cp /etc/leafwiki/.env /etc/leafwiki/.env 2>/dev/null || true
cp /opt/leafwiki/leafwiki.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now leafwiki
