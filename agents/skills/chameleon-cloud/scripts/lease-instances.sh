#!/usr/bin/env bash
# List the instances (servers) that belong to a lease
# by mapping lease -> host reservations -> Blazar hosts -> hypervisors -> servers,
# since instance names do not encode the lease.
#
# Usage: lease-instances.sh <lease-name>
set -euo pipefail

CHI="$(cd "$(dirname "$0")" && pwd)/chi.sh"

LEASE_NAME="${1:?Usage: $0 <lease-name>}"

res_ids=$("$CHI" blazar lease-show "$LEASE_NAME" -f json |
  jq -c '.reservations | map(select(.resource_type == "physical:host") | .id)')
[[ $res_ids != "[]" && -n $res_ids ]] || {
  echo "No physical:host reservations found for lease '$LEASE_NAME'" >&2
  exit 1
}

alloc=$("$CHI" blazar allocation-list host -f json)
hosts=$("$CHI" blazar host-list -f json)
servers=$("$CHI" openstack server list --long -n -f json)

# `any(. == x)` (not `index`) avoids jq treating list index 0 as falsy.
# In `openstack server list --long`, .Host is the hypervisor_hostname.
# shellcheck disable=SC2016 # $resids/$alloc/etc. are jq-program variables bound via --argjson, not shell vars
result=$(jq -n \
  --argjson alloc "$alloc" \
  --argjson hosts "$hosts" \
  --argjson servers "$servers" \
  --argjson resids "$res_ids" '
  ($hosts | map({(.id): .hypervisor_hostname}) | add) as $h2hv
  | [ $alloc[]
      | select([.reservations[].id] as $rs
               | $resids | any(. as $x | $rs | any(. == $x)))
      | $h2hv[.resource_id] ]
  | map(select(. != null)) as $hvs
  | { reserved_hosts: ($hvs | length),
      instances: ( $servers
                   | map(select(.Host as $h
                                | $h != null and ($hvs | any(. == $h))))
                   | sort_by(.Name) ) }')

echo "Lease:          $LEASE_NAME"
printf '%s' "$result" | jq -r '
  "Reserved hosts: \(.reserved_hosts)",
  "Instances:      \(.instances | length)",
  "",
  (.instances[] | "  \(.Name)\t[\(.Status)]\t\(.Networks)")'
