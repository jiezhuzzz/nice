#!/usr/bin/env bash
# Attach the site's floating IP to the first instance of a lease
# Usage: attach-floating-ips.sh <lease-name>
# Uses CHI_SITE env var to determine the floating IP (uc=192.5.87.161, tacc=129.114.108.248)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHI="$SCRIPT_DIR/chi.sh"

LEASE_NAME="${1:?Usage: $0 <lease-name>}"
CHI_SITE="${CHI_SITE:-uc}"

case "$CHI_SITE" in
uc) FLOATING_IP="192.5.87.161" ;;
tacc) FLOATING_IP="129.114.108.248" ;;
*)
  echo "Unknown site: $CHI_SITE" >&2
  exit 1
  ;;
esac

INSTANCE="$LEASE_NAME-1"
echo "Floating IP: $FLOATING_IP (CHI@${CHI_SITE^^})"
echo "Target instance: $INSTANCE"

# Detach from any existing server
echo "Checking if floating IP is currently attached..."
current_server=$("$CHI" openstack floating ip show "$FLOATING_IP" -f json | jaq -r '.port_id // empty')
if [ -n "$current_server" ]; then
  echo "  Detaching from current server..."
  ("$CHI" openstack floating ip unset --port "$FLOATING_IP")
fi

# Attach to the first instance
echo "Attaching $FLOATING_IP to $INSTANCE..."
("$CHI" openstack server add floating ip "$INSTANCE" "$FLOATING_IP")

echo ""
echo "Verifying..."
("$CHI" openstack server list -f json | jaq ".[] | select(.Name | startswith(\"$LEASE_NAME\")) | {Name, Status, Networks}")

echo ""
echo "SSH access:"
echo "  Bastion: ssh cc@$FLOATING_IP"
echo "  Other nodes: ssh -J cc@$FLOATING_IP cc@<private-ip>"
echo "Done."
