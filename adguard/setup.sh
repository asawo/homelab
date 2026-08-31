#!/bin/bash
set -euo pipefail

# Run inside CT 107 after container creation
# Installs Docker + Tailscale, then joins the tailnet (run `tailscale up` manually after this)

apt-get update && apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

curl -fsSL https://tailscale.com/install.sh | sh

mkdir -p /opt/adguard/work /opt/adguard/conf

echo "Docker + Tailscale installed. Run 'tailscale up' to join the tailnet, then 'just push-adguard'."
