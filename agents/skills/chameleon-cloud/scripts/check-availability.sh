#!/usr/bin/env bash
# Summarize Chameleon Cloud host availability per node type
# Usage: check-availability.sh
set -euo pipefail

CHI="$(cd "$(dirname "$0")" && pwd)/chi.sh"

hosts=$("$CHI" blazar host-list --long -f json)
allocations=$("$CHI" blazar allocation-list host -f json)

jq -nr --argjson hosts "$hosts" --argjson alloc "$allocations" --arg now "$(date -u +%Y-%m-%dT%H:%M:%S)" '
  ($alloc
    | map({(.resource_id | tostring): ([.reservations[] | select(.start_date <= $now and .end_date >= $now) | .end_date] | max)})
    | add // {}) as $busy_until
  | $hosts
  | map(. + {busy_until: $busy_until[.id | tostring]})
  | group_by(.node_type)[]
  | (map(select(.busy_until == null and .reservable and (.disabled | not))) | length) as $free
  | (map(select(.busy_until != null)) | length) as $reserved
  | (map(.busy_until // empty) | min) as $next
  | "- \(.[0].node_type): \(length) total, \($free) free, \($reserved) reserved"
    + (if length - $free - $reserved > 0 then ", \(length - $free - $reserved) unreservable" else "" end)
    + (if $next then ", first release \($next)" else "" end)'
