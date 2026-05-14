#!/bin/bash
set -euo pipefail

# Run inside CT 102 after container creation
# Creates a venv, installs copyparty, and enables the systemd service

apt-get update && apt-get install -y python3 python3-venv

mkdir -p /opt/copyparty
python3 -m venv /opt/copyparty/venv
/opt/copyparty/venv/bin/pip install copyparty

cp /opt/copyparty/copyparty.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now copyparty
