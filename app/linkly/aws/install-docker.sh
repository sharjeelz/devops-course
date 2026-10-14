#!/usr/bin/env bash
# Installs Docker and the Docker Compose plugin on Amazon Linux 2023 (module 6). Run it on the
# instance with sudo:   sudo bash install-docker.sh
# Amazon Linux 2023 ships Docker but not the Compose plugin, so the plugin comes from Compose's
# GitHub releases: a pinned version, checked against its published sha256 before it's installed.
set -euo pipefail
COMPOSE_VERSION="v5.6.0"

[ "$(id -u)" = 0 ] || { echo "run me with sudo" >&2; exit 1; }
if ! grep -q '^ID="amzn"' /etc/os-release || ! grep -q '^VERSION_ID="2023"' /etc/os-release; then
  echo "this script is for Amazon Linux 2023" >&2; exit 1
fi

echo "== Docker"
dnf install -y -q docker
if [ "${SKIP_SYSTEMCTL:-0}" != 1 ]; then      # containers (our tests) have no systemd
  systemctl enable --now docker
fi
usermod -aG docker ec2-user 2>/dev/null || true   # ec2-user runs docker without sudo (after logging in again)

echo "== Docker Compose plugin ${COMPOSE_VERSION}"
case "$(uname -m)" in
  x86_64) arch=x86_64 ;;
  aarch64) arch=aarch64 ;;
  *) echo "unsupported CPU: $(uname -m)" >&2; exit 1 ;;
esac
url="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${arch}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/docker-compose" "$url"
curl -fsSL -o "$tmp/docker-compose.sha256" "$url.sha256"
(cd "$tmp" && echo "$(cut -d' ' -f1 docker-compose.sha256)  docker-compose" | sha256sum -c --quiet -) \
  || { echo "checksum mismatch for $url: not installing it" >&2; exit 1; }
install -D -m 0755 "$tmp/docker-compose" /usr/local/lib/docker/cli-plugins/docker-compose

echo "== Installed"
docker --version
docker compose version
echo "Log out and back in (or run 'newgrp docker') so ec2-user can use docker without sudo."
