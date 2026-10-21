#!/usr/bin/env bash
# Attach the site's floating IP to the first instance of a lease
# Usage: attach-floating-ips.sh <lease-name>
set -euo pipefail

CHI="$(cd "$(dirname "$0")" && pwd)/chi.sh"

LEASE_NAME="${1:?Usage: $0 <lease-name>}"
CHI_SITE="${CHI_SITE:-uc}"

case "$CHI_SITE" in
uc) FLOATING_IP="192.5.87.20" ;;
tacc) FLOATING_IP="129.114.108.129" ;;
*)
  echo "Unknown site: $CHI_SITE" >&2
  exit 1
  ;;
esac

INSTANCE="$LEASE_NAME-1"
echo "Floating IP: $FLOATING_IP (CHI@${CHI_SITE^^})"
echo "Target instance: $INSTANCE"

echo "Checking if floating IP is currently attached..."
current_server=$("$CHI" openstack floating ip show "$FLOATING_IP" -f json | jq -r '.port_id // empty')
if [ -n "$current_server" ]; then
  echo "  Detaching from current server..."
  "$CHI" openstack floating ip unset --port "$FLOATING_IP"
fi

echo "Attaching $FLOATING_IP to $INSTANCE..."
"$CHI" openstack server add floating ip "$INSTANCE" "$FLOATING_IP"

echo ""
echo "Verifying..."
"$CHI" openstack server show "$INSTANCE" -f json | jq '{name, status, addresses}'

echo ""
echo "SSH access:"
echo "  Bastion: ssh cc@$FLOATING_IP"
echo "  Other nodes: ssh -J cc@$FLOATING_IP cc@<private-ip>"
echo "Done."
