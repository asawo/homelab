#!/bin/bash
set -euo pipefail

# Run inside CT 104 after container creation
# Installs SFTPGo from the official APT repo and enables the service

apt-get update && apt-get install -y curl gnupg

curl -sS https://ftp.osuosl.org/pub/sftpgo/apt/gpg.key | gpg --dearmor -o /usr/share/keyrings/sftpgo-archive-keyring.gpg
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [signed-by=/usr/share/keyrings/sftpgo-archive-keyring.gpg] https://ftp.osuosl.org/pub/sftpgo/apt ${CODENAME} main" \
  > /etc/apt/sources.list.d/sftpgo.list

apt-get update && apt-get install -y sftpgo

mkdir -p /opt/sftpgo

systemctl enable --now sftpgo
