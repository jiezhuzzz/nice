#!/usr/bin/env bash
# Post-instance setup for Chameleon Cloud bare metal instances
# Usage: setup-instance.sh <ip> [<ip2> ...]
# Set SSH_JUMP=cc@<bastion-ip> to reach nodes via jump host
# Set SSH_KEY=<path> to use a key other than the agenix-decrypted chameleon one
# Set STEPS to a subset of "rclone terminfo apt userns linger nix" to run only those
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <ip> [<ip2> ...]" >&2
  echo "Set SSH_JUMP=cc@<bastion-ip> for nodes behind a bastion" >&2
  exit 1
fi

STEPS="${STEPS:-rclone terminfo apt userns linger nix}"
SSH_KEY="${SSH_KEY:-/run/agenix/chameleon-ssh-key}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY")
if [ -n "${SSH_JUMP:-}" ]; then
  # OpenSSH does not pass -i through to a -J hop, so a non-default SSH_KEY
  # authenticates against the target but not the bastion. Spelling the hop out
  # as a ProxyCommand carries the same identity to both.
  SSH_OPTS+=(-o "ProxyCommand=ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -W %h:%p $SSH_JUMP")
fi
SCP_OPTS=("${SSH_OPTS[@]}" -p)

step_rclone() {
  # Copy rclone OAuth tokens (decrypted by agenix on the operator host).
  # Best-effort: skip with a warning if the operator host has not materialized
  # the secret yet (e.g. fresh checkout, hasn't rebuilt).
  ssh "${SSH_OPTS[@]}" cc@"$1" 'mkdir -p ~/.local/share/rclone'
  for remote in gdrive box; do
    src="/run/agenix/rclone-${remote}-token"
    dst=".local/share/rclone/${remote}-token"
    if [ -r "$src" ]; then
      scp "${SCP_OPTS[@]}" "$src" cc@"$1":"$dst"
      # shellcheck disable=SC2029  # remote path is intentionally expanded client-side
      ssh "${SSH_OPTS[@]}" cc@"$1" "chmod 600 $dst"
    elif [ -e "$src" ]; then
      echo "WARN: $src exists but is not readable by current user; skipping rclone $remote token copy" >&2
    else
      echo "WARN: $src not present on operator host; skipping rclone $remote token copy" >&2
    fi
  done
}

step_terminfo() {
  infocmp -x xterm-ghostty | ssh "${SSH_OPTS[@]}" cc@"$1" -- tic -x -
}

step_apt() {
  ssh "${SSH_OPTS[@]}" cc@"$1" 'sudo apt update && sudo apt upgrade -y && sudo apt install -y uidmap podman slirp4netns'
}

step_userns() {
  # Rootless podman needs unprivileged user namespaces.
  ssh "${SSH_OPTS[@]}" cc@"$1" 'sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 && echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/99-userns.conf'
}

step_linger() {
  # Enable systemd user lingering so the rclone mount and other user services
  # start at boot rather than at next interactive login.
  ssh "${SSH_OPTS[@]}" cc@"$1" 'sudo loginctl enable-linger cc'
}

step_nix() {
  ssh "${SSH_OPTS[@]}" cc@"$1" 'curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm'
}

for step in $STEPS; do
  declare -F "step_$step" >/dev/null || {
    echo "Unknown step: $step" >&2
    exit 1
  }
done

for ip in "$@"; do
  echo "=== Setting up $ip ($STEPS) ==="
  ssh-keygen -R "$ip" 2>/dev/null || true
  for step in $STEPS; do
    "step_$step" "$ip"
  done
  echo "=== $ip setup complete ==="
done
