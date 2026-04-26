#!/usr/bin/env bash
# Launch bare metal instances in batches of 2 (Chameleon Cloud concurrency limit)
# Usage: launch-instances.sh <lease-name> <image> <keypair> <count>
# Requires: OS_PASSWORD env var set, chi.sh in same directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHI="$SCRIPT_DIR/chi.sh"

LEASE_NAME="${1:?Usage: $0 <lease-name> <image> <keypair> <count>}"
IMAGE="${2:?Missing image (e.g. CC-Ubuntu24.04)}"
KEYPAIR="${3:?Missing keypair name}"
COUNT="${4:?Missing instance count}"
BATCH_SIZE=2
POLL_INTERVAL=60

# Get reservation ID and network ID
echo "Fetching reservation and network IDs..."
reservation_id=$("$CHI" blazar lease-show "$LEASE_NAME" -f json | jaq -r '.reservations' | jaq -r 'select(.resource_type=="physical:host") | .id')
net_id=$("$CHI" openstack network show sharednet1 -c id -f value)

if [ -z "$reservation_id" ]; then
  echo "ERROR: Could not find host reservation ID for lease '$LEASE_NAME'" >&2
  exit 1
fi

echo "Reservation ID: $reservation_id"
echo "Network ID: $net_id"
echo "Launching $COUNT instances in batches of $BATCH_SIZE..."
echo ""

for ((batch_start = 1; batch_start <= COUNT; batch_start += BATCH_SIZE)); do
  batch_end=$((batch_start + BATCH_SIZE - 1))
  [ $batch_end -gt "$COUNT" ] && batch_end=$COUNT

  echo "=== Batch: $LEASE_NAME-$batch_start to $LEASE_NAME-$batch_end ==="

  # Launch batch
  for ((i = batch_start; i <= batch_end; i++)); do
    "$CHI" openstack server create \
      --image "$IMAGE" --flavor baremetal --key-name "$KEYPAIR" \
      --nic net-id="$net_id" --hint reservation="$reservation_id" \
      "$LEASE_NAME-$i" -f json | jaq '{Name: .name, Status: .status}'
  done

  # Poll until all instances in this batch are ACTIVE
  while true; do
    all_active=true
    for ((i = batch_start; i <= batch_end; i++)); do
      srv_status=$("$CHI" openstack server show "$LEASE_NAME-$i" -f json | jaq -r '.status')
      echo "$LEASE_NAME-$i: $srv_status"
      if [ "$srv_status" = "ERROR" ]; then
        echo "ERROR: $LEASE_NAME-$i failed to build" >&2
        fault=$("$CHI" openstack server show "$LEASE_NAME-$i" -f json | jaq -r '.fault.message // "unknown"')
        echo "Fault: $fault" >&2
        exit 1
      fi
      [ "$srv_status" != "ACTIVE" ] && all_active=false
    done
    $all_active && break
    echo "Waiting ${POLL_INTERVAL}s..."
    sleep "$POLL_INTERVAL"
  done
  echo "=== Batch $batch_start-$batch_end ACTIVE ==="
  echo ""
done

echo "All $COUNT instances are ACTIVE."
