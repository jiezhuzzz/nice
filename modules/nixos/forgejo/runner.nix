# Forgejo Actions runner — the CI executor for the forge in ./server.nix. One
# globally-scoped runner, jobs executed as podman containers.
#
# ── Registration ───────────────────────────────────────────────────────────
# services.forgejo-runner takes a pre-registered UUID + token pair rather than a
# registration token, so forgejo-runner-token.service registers one itself via
# `forgejo-cli actions register` with a 40-hex shared secret. That secret *is*
# the token, and both Forgejo and the runner derive the UUID from its first 16
# characters (gouuid.FromBytes over their ASCII bytes) — so pinning that prefix
# here makes the UUID static at eval time, which the module needs because it
# has no uuid_url, while the remaining 96 random bits are minted on the box.
# The secret is machine-local and meaningless off this box, which is why it is
# not an agenix secret like the Cloudflare or provider keys. It is minted once
# and kept, so the runner keeps one identity in the admin UI; registration is
# idempotent and re-runs every start. It has to run after forgejo.service
# because the CLI drives Forgejo's internal HTTP API rather than the database.
#
# ── Reaching the forge from inside a job container ─────────────────────────
# Jobs clone from GITHUB_SERVER_URL, which Forgejo fills in from ROOT_URL, so a
# container has to reach https://git.jiezhu.me itself — loopback is its own
# namespace and the tailnet address is not routable from the bridge. Two things
# make that work, and the second is load-bearing for security:
#
#   - --add-host points the name at the podman bridge gateway and the firewall
#     admits :443 there. Jobs are pinned to the default bridge rather than the
#     per-job networks forgejo-runner creates when `network` is empty, so the
#     interface to open is a stable podman0 instead of a fresh 10.89.x bridge
#     every run.
#   - caddy.nix then refuses every vhost except git to a podman-bridge source.
#     Without it a workflow could reach shiori and miniflux through the same
#     front door, whose reverse_proxy blocks *set* an SSO header — CI would
#     arrive already logged in as jie.
#
# The actions cache needs the same treatment, because the proxy URL is handed
# to the container and so has to name an address it can route to. Its port is
# pinned (upstream picks a random one per start) so the firewall can admit
# exactly one, and 8100 stays clear of the 8088-upward range ad-hoc `dsh web`
# runs squat.
{
  config,
  lib,
  ...
}: let
  # podman's default bridge and the gateway address containers see the host as.
  bridge = "podman0";
  gateway = "10.88.0.1";
  cacheProxyPort = 8100;

  domain = config.services.forgejo.settings.server.DOMAIN;
  # The unit services.forgejo-runner derives from the instance name.
  runnerUnit = "forgejo-runner-nixmachine.service";
  secretFile = "/var/lib/forgejo-runner-token/secret";

  secretPrefix = "1c933ccc66353a1a";
  uuid = let
    hex = lib.concatMapStrings (c: lib.toLower (lib.toHexString (lib.strings.charToInt c))) (lib.stringToCharacters secretPrefix);
    part = start: len: builtins.substring start len hex;
  in "${part 0 8}-${part 8 4}-${part 12 4}-${part 16 4}-${part 20 12}";
in {
  services.forgejo-runner.instances.nixmachine = {
    enable = true;
    secrets.server.connections.default.token_url = secretFile;

    settings = {
      server.connections.default = {
        # No trailing slash: the runner appends its own paths to this.
        url = "https://${domain}";
        inherit uuid;
      };

      # `ubuntu-latest` so workflows lifted from GitHub match without an edit.
      # A plain tag rather than a digest like the oci-containers pins
      # elsewhere: this is the image a *job* runs in, and pinning it would
      # freeze CI's toolchain to whatever was current the day this was written.
      runner.labels = [
        "ubuntu-latest:docker://node:24-bookworm"
        "docker:docker://node:24-bookworm"
      ];

      container = {
        network = "bridge";
        options = "--add-host=${domain}:${gateway}";
      };
      cache = {
        host = gateway;
        proxy_port = cacheProxyPort;
      };
    };
  };

  systemd.services.forgejo-runner-token = {
    description = "Mint, persist and register the Forgejo Actions runner secret";
    after = ["forgejo.service"];
    requires = ["forgejo.service"];
    before = [runnerUnit];
    requiredBy = [runnerUnit];
    path = [config.services.forgejo.package];

    environment = {
      FORGEJO_WORK_DIR = config.services.forgejo.stateDir;
      FORGEJO_CUSTOM = config.services.forgejo.customDir;
    };

    # Assign before writing, and assert the length: `set -e` does not trip on a
    # command substitution that fails inside an argument list, so writing the
    # random half inline would persist a bare prefix on a failed read — and the
    # file test below would then read as done and never retry.
    script = ''
      if [ ! -s '${secretFile}' ]; then
        random=$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')
        [ "''${#random}" -eq 24 ]
        printf '%s%s' '${secretPrefix}' "$random" > '${secretFile}'
      fi
      forgejo forgejo-cli actions register --secret-file '${secretFile}' --name nixmachine
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = config.services.forgejo.user;
      Group = config.services.forgejo.group;
      StateDirectory = "forgejo-runner-token";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
  };

  # Scoped to the bridge, so this admits job containers and nothing off-box:
  # caddy for the clone/artifact traffic, and the runner's own cache proxy.
  networking.firewall.interfaces.${bridge}.allowedTCPPorts = [443 cacheProxyPort];
}
