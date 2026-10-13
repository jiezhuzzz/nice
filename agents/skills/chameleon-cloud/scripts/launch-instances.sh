#!/usr/bin/env bash
# Launch bare metal instances in batches of 2 (Chameleon Cloud concurrency limit)
# Usage: launch-instances.sh <lease-name> <image> <keypair> <count>
set -euo pipefail

CHI="$(cd "$(dirname "$0")" && pwd)/chi.sh"

LEASE_NAME="${1:?Usage: $0 <lease-name> <image> <keypair> <count>}"
IMAGE="${2:?Missing image (e.g. CC-Ubuntu24.04)}"
KEYPAIR="${3:?Missing keypair name}"
COUNT="${4:?Missing instance count}"
BATCH_SIZE=2
POLL_INTERVAL=60

echo "Fetching reservation ID..."
reservation_id=$("$CHI" blazar lease-show "$LEASE_NAME" -f json | jq -r '.reservations[] | select(.resource_type=="physical:host") | .id')

if [ -z "$reservation_id" ]; then
  echo "ERROR: Could not find host reservation ID for lease '$LEASE_NAME'" >&2
  exit 1
fi

echo "Reservation ID: $reservation_id"
echo "Launching $COUNT instances in batches of $BATCH_SIZE..."
echo ""

for ((batch_start = 1; batch_start <= COUNT; batch_start += BATCH_SIZE)); do
  batch_end=$((batch_start + BATCH_SIZE - 1))
  [ $batch_end -gt "$COUNT" ] && batch_end=$COUNT

  echo "=== Batch: $LEASE_NAME-$batch_start to $LEASE_NAME-$batch_end ==="

  for ((i = batch_start; i <= batch_end; i++)); do
    "$CHI" openstack server create \
      --image "$IMAGE" --flavor baremetal --key-name "$KEYPAIR" \
      --network sharednet1 --hint reservation="$reservation_id" \
      "$LEASE_NAME-$i" -f json | jq '{Name: .name, Status: .status}'
  done

  while true; do
    all_active=true
    for ((i = batch_start; i <= batch_end; i++)); do
      srv=$("$CHI" openstack server show "$LEASE_NAME-$i" -f json)
      srv_status=$(jq -r '.status' <<<"$srv")
      echo "$LEASE_NAME-$i: $srv_status"
      if [ "$srv_status" = "ERROR" ]; then
        echo "ERROR: $LEASE_NAME-$i failed to build" >&2
        echo "Fault: $(jq -r '.fault.message // "unknown"' <<<"$srv")" >&2
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
