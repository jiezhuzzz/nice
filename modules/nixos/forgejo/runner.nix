# Forgejo Actions runner — the CI executor for the forge in ./server.nix. One
# globally-scoped runner, jobs executed as podman containers.
#
# `package` is deliberately forgejo-runner rather than the module's
# gitea-actions-runner default: the two forks' runner protocols drift, and this
# talks to Forgejo.
#
# ── Registration ───────────────────────────────────────────────────────────
# A runner registers with a token the *server* mints, so there is nothing to
# author by hand and nothing worth encrypting: the token is machine-local and
# meaningless off this box, which is why it is not an agenix secret like the
# Cloudflare or provider keys. forgejo-runner-token.service below mints one and
# keeps it. Keeping it matters — the runner module re-registers whenever the
# token's hash changes, so a fresh token per boot would leave a trail of dead
# runners in the admin UI. It has to run after forgejo.service because the CLI
# drives Forgejo's internal HTTP API rather than the database.
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
  pkgs,
  ...
}: let
  # podman's default bridge and the gateway address containers see the host as.
  bridge = "podman0";
  gateway = "10.88.0.1";
  cacheProxyPort = 8100;

  domain = config.services.forgejo.settings.server.DOMAIN;
  # The unit services.gitea-actions-runner derives from the instance name.
  runnerUnit = "gitea-runner-nixmachine.service";
  tokenFile = "/var/lib/forgejo-runner-token/env";
in {
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;

    instances.nixmachine = {
      enable = true;
      name = "nixmachine";
      # No trailing slash: the runner appends its own paths to this.
      url = "https://${domain}";
      inherit tokenFile;

      # `ubuntu-latest` so workflows lifted from GitHub match without an edit.
      # A plain tag rather than a digest like the oci-containers pins
      # elsewhere: this is the image a *job* runs in, and pinning it would
      # freeze CI's toolchain to whatever was current the day this was written.
      labels = [
        "ubuntu-latest:docker://node:24-bookworm"
        "docker:docker://node:24-bookworm"
      ];

      settings = {
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
  };

  systemd.services.forgejo-runner-token = {
    description = "Mint and persist the Forgejo Actions runner registration token";
    after = ["forgejo.service"];
    requires = ["forgejo.service"];
    before = [runnerUnit];
    requiredBy = [runnerUnit];
    path = [config.services.forgejo.package];

    environment = {
      FORGEJO_WORK_DIR = config.services.forgejo.stateDir;
      FORGEJO_CUSTOM = config.services.forgejo.customDir;
    };

    # Assign before writing, and assert non-empty: `set -e` does not trip on a
    # command substitution that fails inside an argument list, so writing the
    # token inline would persist a bare `TOKEN=` on a failed mint — and the
    # file test below would then read as done and never retry.
    script = ''
      if [ ! -s '${tokenFile}' ]; then
        token=$(forgejo forgejo-cli actions generate-runner-token)
        [ -n "$token" ]
        printf 'TOKEN=%s\n' "$token" > '${tokenFile}'
      fi
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
