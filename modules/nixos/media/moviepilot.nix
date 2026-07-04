# MoviePilot V2 — all-in-one media automation (subscription, search, download,
# organize) built for the Chinese PT ecosystem (M-Team) + Douban. Trialled as a
# potential replacement for the *arr stack, whose IMDb-ID search can't surface
# M-Team's un-tagged releases (see the sonarr/M-Team debugging in the spec).
#
# Runs as an OCI container on podman (backend is set in metatube.nix). Full
# integration: it shares /tank/media with the *arr apps, so it runs as a
# dedicated `moviepilot` user in the `media` group (PGID) with UMASK=002 — its
# imports hardlink into the library exactly like radarr/sonarr. The single
# /tank/media mount (not split downloads/library) is what makes hardlinks work
# across the container boundary.
#
# First boot downloads a ~206MB "CloakBrowser" (stealth Chromium for anti-bot
# scraping — useful against M-Team's Cloudflare) and auto-generates the admin
# password, printed ONCE in the logs (`journalctl -u podman-moviepilot` /
# `podman logs moviepilot`). See the runbook in the design spec.
#
# Image pinned by digest. API_TOKEN comes from a root-only env file out of the
# Nix store (recyclarr pattern) — create it before the container will start.
{config, ...}: {
  users.groups.moviepilot = {};
  users.users.moviepilot = {
    isSystemUser = true;
    uid = 984;
    group = "moviepilot";
    extraGroups = ["media"]; # read Transmission's downloads + write the library
    description = "MoviePilot container identity";
  };

  virtualisation.oci-containers.containers.moviepilot = {
    image = "docker.io/jxxghp/moviepilot-v2@sha256:27919c55cc65c920eb566cc2890f7ffce5baed5f5251d69ddc0b58361ba544c7";
    ports = ["3000:3000"]; # LAN — firewall.nix opens 3000 to the home subnet
    volumes = [
      "/var/lib/moviepilot:/config"
      "/tank/media:/tank/media" # one mount → downloads+library one tree → hardlinks
      "/var/lib/moviepilot-cloak:/moviepilot/.cloakbrowser" # persist the ~206MB CloakBrowser across recreates
    ];
    environment = {
      PUID = toString config.users.users.moviepilot.uid; # 984
      PGID = "991"; # `media` group; config.users.groups.media.gid is null at eval
      UMASK = "002"; # group-writable imports → hardlinkable, like the *arr apps
      TZ = "America/Chicago";
      SUPERUSER = "admin"; # username; initial password is auto-generated (see logs)
    };
    environmentFiles = ["/var/lib/moviepilot-secrets/env"]; # holds API_TOKEN=...
  };

  # /config is moviepilot-owned; secrets dir is root-only (holds the API_TOKEN
  # env file, read by podman at container start).
  systemd.tmpfiles.rules = [
    "d /var/lib/moviepilot         0750 moviepilot moviepilot -"
    "d /var/lib/moviepilot-cloak   0750 moviepilot moviepilot -"
    "d /var/lib/moviepilot-secrets 0700 root       root       -"
  ];
}
