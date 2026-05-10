#!/usr/bin/env bash
# Chameleon Cloud CLI wrapper
# Usage: CHI_SITE=uc|tacc chi blazar <args...>  OR  chi openstack <args...>
set -euo pipefail

CHI_SITE="${CHI_SITE:-uc}"

export OS_IDENTITY_API_VERSION="3"
export OS_INTERFACE="public"
export OS_USERNAME="jiezhu@uchicago.edu"
export OS_PROTOCOL="openid"
export OS_AUTH_TYPE="v3oidcpassword"
export OS_IDENTITY_PROVIDER="chameleon"
export OS_DISCOVERY_ENDPOINT="https://auth.chameleoncloud.org/auth/realms/chameleon/.well-known/openid-configuration"
export OS_ACCESS_TOKEN_TYPE="access_token"
export OS_CLIENT_SECRET="none"

case "$CHI_SITE" in
uc)
  export OS_AUTH_URL="https://chi.uc.chameleoncloud.org:5000/v3"
  export OS_PROJECT_ID="e46d806797dc438bbd703f97533ca4d6"
  export OS_CLIENT_ID="keystone-uc-prod"
  export OS_REGION_NAME="CHI@UC"
  ;;
tacc)
  export OS_AUTH_URL="https://chi.tacc.chameleoncloud.org:5000/v3"
  export OS_PROJECT_ID="4887042746b44fdba6f7a114efb6126f"
  export OS_CLIENT_ID="keystone-tacc-prod"
  export OS_REGION_NAME="CHI@TACC"
  ;;
*)
  echo "Unknown site: $CHI_SITE (use 'uc' or 'tacc')" >&2
  exit 1
  ;;
esac

if [[ -z ${OS_PASSWORD:-} ]]; then
  echo "Error: OS_PASSWORD must be set" >&2
  exit 1
fi

cmd="${1:?Usage: chi <blazar|openstack> [args...]}"
shift

case "$cmd" in
blazar)
  exec uvx --from python-blazarclient blazar "$@"
  ;;
openstack)
  exec uvx --from python-openstackclient openstack "$@"
  ;;
*)
  echo "Unknown command: $cmd (use 'blazar' or 'openstack')" >&2
  exit 1
  ;;
esac
