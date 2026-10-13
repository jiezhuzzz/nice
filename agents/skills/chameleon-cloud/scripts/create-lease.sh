#!/usr/bin/env bash
# Create a physical:host lease starting now and wait until it is ACTIVE
# Usage: create-lease.sh <name> <node-type> <count> <end-date>
# Example: create-lease.sh my-lease compute_skylake 2 "2026-03-15 00:00"
set -euo pipefail

CHI="$(cd "$(dirname "$0")" && pwd)/chi.sh"

LEASE_NAME="${1:?Usage: $0 <name> <node-type> <count> <end-date>}"
NODE_TYPE="${2:?Missing node_type (e.g. compute_skylake, compute_cascadelake_r)}"
COUNT="${3:?Missing node count}"
END_DATE="${4:?Missing end date (e.g. '2026-03-15 00:00')}"
POLL_INTERVAL=5
TIMEOUT=120

echo "Creating lease '$LEASE_NAME'..."
echo "  Node type: $NODE_TYPE"
echo "  Count: $COUNT"
echo "  End date: $END_DATE"

"$CHI" blazar lease-create \
  --reservation "min=$COUNT,max=$COUNT,resource_type=physical:host,resource_properties=[\"=\",\"\$node_type\",\"$NODE_TYPE\"]" \
  --end-date "$END_DATE" \
  "$LEASE_NAME"

echo "Polling lease status (timeout ${TIMEOUT}s)..."
elapsed=0
while [ $elapsed -lt $TIMEOUT ]; do
  status=$("$CHI" blazar lease-show "$LEASE_NAME" -f json | jq -r '.status')
  echo "  Status: $status (${elapsed}s)"
  if [ "$status" = "ACTIVE" ]; then
    echo "Lease '$LEASE_NAME' is ACTIVE."
    exit 0
  elif [ "$status" = "ERROR" ]; then
    echo "ERROR: Lease creation failed." >&2
    exit 1
  fi
  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
done

echo "ERROR: Timed out waiting for lease to become ACTIVE." >&2
exit 1
