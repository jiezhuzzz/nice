# Agent-assisted hardlink-on-completion. Transmission's script-torrent-done hook
# drops a TR_* job file into the download-dir (the one path writable inside its
# sandbox); a systemd.path watcher fires media-filer.service — a separate,
# least-privilege unit with RW on /tank/media — which parses the release
# (guessit), optionally asks Claude for a JSON classification, and hardlinks it
# into the Jellyfin library. Claude only advises; the Python app is the sole
# thing that touches the filesystem. See
# docs/superpowers/specs/2026-07-05-media-filer-design.md
{pkgs, ...}: let
  media-filer = pkgs.python3.pkgs.buildPythonApplication {
    pname = "media-filer";
    version = "0.1.0";
    pyproject = true;
    src = ./filer;
    build-system = [pkgs.python3.pkgs.hatchling];
    dependencies = [pkgs.python3.pkgs.guessit];
    doCheck = false; # tests are the dev loop (uv), not the build
  };

  queue = "/tank/media/downloads/.filer-queue";

  # Runs inside Transmission's sandbox as the `transmission` user. Does the bare
  # minimum and returns instantly: atomically drop a TR_* dump into the queue.
  doneHook = pkgs.writeShellScript "transmission-done-filer" ''
    set -eu
    umask 0002
    tmp="${queue}/''${TR_TORRENT_HASH}.job.tmp"
    # Dump TR_* but redact tracker passkeys: private-tracker announce URLs in
    # TR_TORRENT_TRACKERS embed the passkey, and only hostnames are needed
    # downstream, so keep the secret out of the on-disk queue file.
    ${pkgs.coreutils}/bin/env | ${pkgs.gnugrep}/bin/grep '^TR_' \
      | ${pkgs.gnused}/bin/sed -E 's/(passkey|authkey)=[^&[:space:],]*/\1=REDACTED/g' > "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" "${queue}/''${TR_TORRENT_HASH}.job"
  '';
in {
  # Dedicated no-login user; group `media` grants RW on the library via setgid dirs.
  users.users.media-filer = {
    isSystemUser = true;
    group = "media";
    description = "Files completed torrents into the Jellyfin library";
    home = "/var/lib/media-filer";
  };

  # Queue dir (transmission writes as owner, media-filer deletes via the media
  # group) plus the root-only secrets dir for the Claude key env file.
  systemd.tmpfiles.rules = [
    "d ${queue} 2775 transmission media -"
    "d /var/lib/media-filer-secrets 0700 root root -"
  ];

  # Wire the hook into Transmission (kept here so transmission.nix stays a pure
  # daemon config).
  services.transmission.settings = {
    script-torrent-done-enabled = true;
    script-torrent-done-filename = "${doneHook}";
  };

  # Fire the filer whenever the queue is non-empty; it re-arms after each drain.
  systemd.paths.media-filer = {
    wantedBy = ["multi-user.target"];
    pathConfig.DirectoryNotEmpty = queue;
  };

  systemd.services.media-filer = {
    description = "File completed torrents into the Jellyfin library";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    path = [pkgs.claude-code]; # provides `claude` for the advisory fallback
    serviceConfig = {
      Type = "oneshot";
      User = "media-filer";
      Group = "media";
      ExecStart = "${media-filer}/bin/media-filer ${queue}";

      # Writable HOME/state for Claude (config/cache/creds + future ~/.claude/skills).
      StateDirectory = "media-filer";
      Environment = ["HOME=/var/lib/media-filer"];
      EnvironmentFile = "-/var/lib/media-filer-secrets/env"; # ANTHROPIC_API_KEY, root-only

      # Least privilege. BindPaths (not ReadWritePaths — the latter does not
      # produce writable mounts under our ZFS strict sandbox) makes the library
      # writable. Network egress stays allowed (Claude needs it).
      ProtectSystem = "strict";
      BindPaths = ["/tank/media"];
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
