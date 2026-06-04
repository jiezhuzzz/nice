#!/usr/bin/env bash
# List the instances (servers) that belong to a lease.
#
# Instance NAMES do not encode the lease they run on (the launch script just
# numbers them <lease>-1, <lease>-2, ... and the counter can continue past a
# lease's node count), so NEVER match instances to a lease by name prefix.
# This maps reliably: lease -> host reservation id(s) -> Blazar host id(s) ->
# hypervisor_hostname(s) -> the server scheduled on that hypervisor.
#
# Usage: lease-instances.sh <lease-name>
# Requires: OS_PASSWORD (and CHI_SITE) env vars set, chi.sh in same directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHI="$SCRIPT_DIR/chi.sh"
# Prefer jaq (faster) but fall back to jq; one of them must exist.
JQ="${JQ:-$(command -v jaq || command -v jq || true)}"
[[ -n $JQ ]] || {
  echo "Error: need 'jaq' or 'jq' on PATH" >&2
  exit 1
}

LEASE_NAME="${1:?Usage: $0 <lease-name>}"

# 1. Host reservation id(s) for this lease, as a JSON array.
#    Blazar's .reservations is a string holding one OR MORE JSON objects
#    concatenated (not a JSON array). Pipe the raw string into a second jq
#    with -s, which parses the concatenated objects as a stream and slurps
#    them into an array — this handles both single- and multi-reservation
#    leases (e.g. a host reservation plus a floating-ip reservation).
res_ids=$("$CHI" blazar lease-show "$LEASE_NAME" -f json | "$JQ" -r '.reservations' |
  "$JQ" -s -c 'map(select(.resource_type == "physical:host") | .id)')
[[ $res_ids != "[]" && -n $res_ids ]] || {
  echo "No physical:host reservations found for lease '$LEASE_NAME'" >&2
  exit 1
}

# 2. Fetch allocations, hosts, and servers once.
alloc=$("$CHI" blazar allocation-list host -f json)
hosts=$("$CHI" blazar host-list -f json)
servers=$("$CHI" openstack server list --long -f json)

# 3. Single join: reservation ids -> host ids -> hypervisors -> servers.
#    `any(. == x)` (not `index`) avoids jq treating list index 0 as falsy.
#    In `openstack server list --long`, .Host is the hypervisor_hostname.
# shellcheck disable=SC2016 # $resids/$alloc/etc. are jq-program variables bound via --argjson, not shell vars
result=$("$JQ" -n \
  --argjson alloc "$alloc" \
  --argjson hosts "$hosts" \
  --argjson servers "$servers" \
  --argjson resids "$res_ids" '
  ($hosts | map({(.id): .hypervisor_hostname}) | add) as $h2hv
  | [ $alloc[]
      | select([.reservations[]?.id] as $rs
               | $resids | any(. as $x | $rs | any(. == $x)))
      | $h2hv[.resource_id] ]
  | map(select(. != null)) as $hvs
  | { reserved_hosts: ($hvs | length),
      instances: ( $servers
                   | map(select(.Host as $h
                                | $h != null and ($hvs | any(. == $h))))
                   | sort_by(.Name) ) }')

echo "Lease:          $LEASE_NAME"
printf '%s' "$result" | "$JQ" -r '
  "Reserved hosts: \(.reserved_hosts)",
  "Instances:      \(.instances | length)",
  "",
  (.instances[] | "  \(.Name)\t[\(.Status)]\t\(.Networks)")'
