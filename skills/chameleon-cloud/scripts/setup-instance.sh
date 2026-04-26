#!/usr/bin/env bash
# Post-instance setup for Chameleon Cloud bare metal instances
# Usage: setup-instance.sh <ip> [<ip2> ...]
# Set SSH_JUMP=cc@<bastion-ip> to reach nodes via jump host
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <ip> [<ip2> ...]" >&2
  echo "Set SSH_JUMP=cc@<bastion-ip> for nodes behind a bastion" >&2
  exit 1
fi

SSH_KEY="${SSH_KEY:-$HOME/.ssh/cc.private}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY")
SCP_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY" -p)
if [ -n "${SSH_JUMP:-}" ]; then
  SSH_OPTS+=(-J "$SSH_JUMP")
  SCP_OPTS+=(-J "$SSH_JUMP")
fi

for ip in "$@"; do
  echo "=== Setting up $ip ==="

  # Remove stale host key
  ssh-keygen -R "$ip" 2>/dev/null || true

  # Copy env files and op-token
  scp "${SCP_OPTS[@]}" ~/.envs cc@"$ip":~/.envs
  scp "${SCP_OPTS[@]}" ~/.op-token cc@"$ip":~/.op-token

  # Copy Ghostty terminfo
  infocmp -x xterm-ghostty | ssh "${SSH_OPTS[@]}" cc@"$ip" -- tic -x -

  # System update and install podman dependencies
  ssh "${SSH_OPTS[@]}" cc@"$ip" 'sudo apt update && sudo apt upgrade -y && sudo apt install -y uidmap podman slirp4netns'

  # Allow unprivileged user namespaces (required for podman rootless)
  ssh "${SSH_OPTS[@]}" cc@"$ip" 'sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 && echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/99-userns.conf'

  # Install Nix
  ssh "${SSH_OPTS[@]}" cc@"$ip" 'curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm'

  echo "=== $ip setup complete ==="
done
