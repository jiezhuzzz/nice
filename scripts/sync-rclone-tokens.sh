#!/usr/bin/env bash
# Sync rclone OAuth tokens to standalone home-manager lab nodes (goku, vegeta).
#
# Those Linux hosts have no system-level agenix, so the rclone home-manager
# module (modules/home-manager/common/rclone.nix) reads the GDrive/Box tokens
# from ~/.local/share/rclone/{gdrive,box}-token instead of /run/agenix. This
# copies the tokens that agenix has already decrypted on THIS machine (the
# operator, e.g. a Mac that is a secrets recipient) to each node.
#
# Run this BEFORE the first `home-manager switch --flake ...#<host>` on a node:
# if the tokens are missing at activation, rclone-config.service fails and the
# rclone-mount:@{gdrive,box}.service units never start. Recovery after dropping
# them in:
#   systemctl --user start rclone-config.service
#   systemctl --user start 'rclone-mount:@gdrive.service' 'rclone-mount:@box.service'
#
# Usage: sync-rclone-tokens.sh [host ...]   (defaults to: goku vegeta)
# Hosts must be reachable via your ssh config — goku/vegeta route through the
# `uchicago` ProxyJump as user jiezzz (see profiles/*-desktop.nix), so apply
# that config (darwin-rebuild/home-manager switch) on this machine first.
set -euo pipefail

HOSTS=("$@")
[ "${#HOSTS[@]}" -eq 0 ] && HOSTS=(goku vegeta)

for host in "${HOSTS[@]}"; do
  echo "=== $host ==="
  ssh "$host" 'mkdir -p ~/.local/share/rclone'
  for remote in gdrive box; do
    src="/run/agenix/rclone-${remote}-token"
    dst=".local/share/rclone/${remote}-token"
    if [ -r "$src" ]; then
      scp -p "$src" "$host:$dst"
      # shellcheck disable=SC2029  # remote path is intentionally expanded client-side
      ssh "$host" "chmod 600 $dst"
      echo "  copied $remote token"
    elif [ -e "$src" ]; then
      echo "  WARN: $src exists but is not readable by you; skipping $remote" >&2
    else
      echo "  WARN: $src not present on this host (rebuild to materialize it?); skipping $remote" >&2
    fi
  done
done

echo
echo "Done. Now activate on each node (tokens must already be in place):"
for host in "${HOSTS[@]}"; do
  echo "  home-manager switch --flake github:jiezhuzzz/nice#$host"
done
