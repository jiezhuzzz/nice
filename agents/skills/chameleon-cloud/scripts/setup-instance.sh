#!/usr/bin/env bash
# Post-instance setup for Chameleon Cloud bare metal instances
# Usage: setup-instance.sh <ip> [<ip2> ...]
# Set SSH_JUMP=cc@<bastion-ip> to reach nodes via jump host
# Set SSH_KEY=<path> to use a key other than the agenix-decrypted chameleon one
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <ip> [<ip2> ...]" >&2
  echo "Set SSH_JUMP=cc@<bastion-ip> for nodes behind a bastion" >&2
  exit 1
fi

SSH_KEY="${SSH_KEY:-/run/agenix/chameleon-ssh-key}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY")
SCP_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY" -p)
if [ -n "${SSH_JUMP:-}" ]; then
  # OpenSSH does not pass -i through to a -J hop, so a non-default SSH_KEY
  # authenticates against the target but not the bastion. Spelling the hop out
  # as a ProxyCommand carries the same identity to both.
  JUMP_OPTS=(-o "ProxyCommand=ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -W %h:%p $SSH_JUMP")
  SSH_OPTS+=("${JUMP_OPTS[@]}")
  SCP_OPTS+=("${JUMP_OPTS[@]}")
fi

for ip in "$@"; do
  echo "=== Setting up $ip ==="

  ssh-keygen -R "$ip" 2>/dev/null || true

  # Copy rclone OAuth tokens (decrypted by agenix on the operator host).
  # Best-effort: skip with a warning if the operator host has not materialized
  # the secret yet (e.g. fresh checkout, hasn't rebuilt).
  ssh "${SSH_OPTS[@]}" cc@"$ip" 'mkdir -p ~/.local/share/rclone'
  for remote in gdrive box; do
    src="/run/agenix/rclone-${remote}-token"
    dst=".local/share/rclone/${remote}-token"
    if [ -r "$src" ]; then
      scp "${SCP_OPTS[@]}" "$src" cc@"$ip":"$dst"
      # shellcheck disable=SC2029  # remote path is intentionally expanded client-side
      ssh "${SSH_OPTS[@]}" cc@"$ip" "chmod 600 $dst"
    elif [ -e "$src" ]; then
      echo "WARN: $src exists but is not readable by current user; skipping rclone $remote token copy" >&2
    else
      echo "WARN: $src not present on operator host; skipping rclone $remote token copy" >&2
    fi
  done

  infocmp -x xterm-ghostty | ssh "${SSH_OPTS[@]}" cc@"$ip" -- tic -x -

  ssh "${SSH_OPTS[@]}" cc@"$ip" 'sudo apt update && sudo apt upgrade -y && sudo apt install -y uidmap podman slirp4netns'

  # Rootless podman needs unprivileged user namespaces.
  ssh "${SSH_OPTS[@]}" cc@"$ip" 'sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 && echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/99-userns.conf'

  # Enable systemd user lingering so the rclone mount and other user services
  # start at boot rather than at next interactive login.
  ssh "${SSH_OPTS[@]}" cc@"$ip" 'sudo loginctl enable-linger cc'

  ssh "${SSH_OPTS[@]}" cc@"$ip" 'curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm'

  echo "=== $ip setup complete ==="
done
