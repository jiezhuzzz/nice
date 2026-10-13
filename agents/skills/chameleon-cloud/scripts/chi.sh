#!/usr/bin/env bash
# Chameleon Cloud CLI wrapper, authenticated through ccauth's OIDC device flow
# Usage: CHI_SITE=uc|tacc chi.sh <login|logout|blazar|openstack|cc-login> [args...]
set -euo pipefail

CHI_SITE="${CHI_SITE:-uc}"
# ccauth is not published on PyPI; Chameleon's docs install it from git. Pinned
# so uv's cache hits instead of fetching the repo on every call.
CCAUTH="git+https://github.com/ChameleonCloud/ccauth.git@7650b494eb79c6ac0beccac114081f88e22bb167"
# The scripts parse this client's -f json shapes; upstream python-blazarclient
# renders lease-show's .reservations as a string instead of an array.
BLAZARCLIENT="chameleon-blazarclient==3.6.5"
STATE_DIR="${CC_LOGIN_STATE:-$HOME/.cache/ccauth}"
TOKEN_CACHE="$STATE_DIR/refresh_token.json"

export OS_IDENTITY_API_VERSION="3"
export OS_INTERFACE="public"
export OS_AUTH_TYPE="v3chameleonoidc"
export OS_IDENTITY_PROVIDER="chameleon"
export OS_PROTOCOL="openid"
export OS_CLIENT_ID="chi-cli-device-token"
export OS_DISCOVERY_ENDPOINT="https://auth.chameleoncloud.org/auth/realms/chameleon/.well-known/openid-configuration"
# keystoneauth's argparse loading passes None for unset plugin options, which
# overrides the plugin's own default; ccauth then indexes the token response
# with None, swallows the KeyError, and silently falls back to the device flow.
export OS_ACCESS_TOKEN_TYPE="access_token"

case "$CHI_SITE" in
uc)
  export OS_AUTH_URL="https://chi.uc.chameleoncloud.org:5000/v3"
  export OS_PROJECT_ID="e46d806797dc438bbd703f97533ca4d6"
  export OS_REGION_NAME="CHI@UC"
  ;;
tacc)
  export OS_AUTH_URL="https://chi.tacc.chameleoncloud.org:5000/v3"
  export OS_PROJECT_ID="4887042746b44fdba6f7a114efb6126f"
  export OS_REGION_NAME="CHI@TACC"
  ;;
*)
  echo "Unknown site: $CHI_SITE (use 'uc' or 'tacc')" >&2
  exit 1
  ;;
esac

site_args=(--auth-url "$OS_AUTH_URL" --region-name "$OS_REGION_NAME" --project-id "$OS_PROJECT_ID")

require_login() {
  # Without a cached refresh token the auth plugin falls back to the device
  # flow and blocks until someone approves it in a browser.
  [[ -s $TOKEN_CACHE ]] || {
    echo "Error: no cached ccauth login at $TOKEN_CACHE; run '$0 login' first" >&2
    exit 1
  }
}

cmd="${1:?Usage: chi.sh <login|logout|blazar|openstack|cc-login> [args...]}"
shift

case "$cmd" in
login)
  exec uvx --from "$CCAUTH" ccauth login "${site_args[@]}" "$@"
  ;;
logout)
  exec uvx --from "$CCAUTH" ccauth logout "$@"
  ;;
cc-login)
  # cc-login keeps one cache file regardless of site, so without a per-site
  # path it would hand back the other site's application credential.
  exec uvx --from "$CCAUTH" cc-login "${site_args[@]}" \
    --app-cred-cache-path "$STATE_DIR/chameleon-app-cred-$CHI_SITE.json" "$@"
  ;;
blazar)
  require_login
  exec uvx --from "$BLAZARCLIENT" --with "$CCAUTH" blazar "$@"
  ;;
openstack)
  require_login
  exec uvx --from python-openstackclient --with "$CCAUTH" openstack "$@"
  ;;
*)
  echo "Unknown command: $cmd (use login, logout, blazar, openstack or cc-login)" >&2
  exit 1
  ;;
esac
