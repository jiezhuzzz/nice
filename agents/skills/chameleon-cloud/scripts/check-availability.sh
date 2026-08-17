#!/usr/bin/env bash
# Check Chameleon Cloud host availability and print a summary
# Usage: check-availability.sh
# Requires: OS_PASSWORD env var set, chi.sh in same directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHI="$SCRIPT_DIR/chi.sh"
# Prefer jaq (faster) but fall back to jq; one of them must exist.
JQ="${JQ:-$(command -v jaq || command -v jq || true)}"
[[ -n $JQ ]] || {
  echo "Error: need 'jaq' or 'jq' on PATH" >&2
  exit 1
}

echo "Fetching hosts..."
hosts=$("$CHI" blazar host-list -f json)
host_ids=$(echo "$hosts" | "$JQ" -r '.[].id')

echo "Fetching allocations..."
allocations=$("$CHI" blazar allocation-list host -f json)

now=$(date -u +%Y-%m-%dT%H:%M:%S)
# shellcheck disable=SC2016 # $now is a jq-program variable bound via --arg, not a shell var
allocated_ids=$(echo "$allocations" | "$JQ" -r --arg now "$now" '
  .[] | select((.reservations | if type == "string" then fromjson else . end) | any(
    .start_date <= $now and .end_date >= $now
  )) | .resource_id
')

declare -A total reserved free
for id in $host_ids; do
  node_type=$("$CHI" blazar host-show "$id" -f json | "$JQ" -r '.node_type')
  total[$node_type]=$((${total[$node_type]:-0} + 1))

  if echo "$allocated_ids" | grep -q "^${id}$"; then
    reserved[$node_type]=$((${reserved[$node_type]:-0} + 1))
  else
    free[$node_type]=$((${free[$node_type]:-0} + 1))
  fi
done

echo ""
echo "Node Availability Summary:"
for nt in "${!total[@]}"; do
  t=${total[$nt]}
  r=${reserved[$nt]:-0}
  f=${free[$nt]:-0}
  echo "- $nt: $t total, $f free, $r reserved"
done
