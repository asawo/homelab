#!/bin/bash
set -euo pipefail

# Run inside CT 105 after container creation
# Downloads FileBrowser Quantum binary, creates a service user, and enables the systemd service

apt-get update && apt-get install -y curl

LATEST=$(curl -sL https://api.github.com/repos/gtsteffaniak/filebrowser/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
curl -fsSL "https://github.com/gtsteffaniak/filebrowser/releases/download/${LATEST}/linux-amd64-filebrowser" -o /usr/local/bin/filebrowser
chmod +x /usr/local/bin/filebrowser

useradd -r -s /bin/false filebrowser

mkdir -p /opt/filebrowser
cp /opt/filebrowser/config.yaml /opt/filebrowser/config.yaml 2>/dev/null || true
chown -R filebrowser:filebrowser /opt/filebrowser

cp /opt/filebrowser/filebrowser.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now filebrowser
