# modules/nixos/media/mediahub.nix
# mediahub — faceted PT search/grab web app (mediahub-web) + the completion filer
# binary (mediahub-file, run by Transmission's hook — wired in a later edit to this
# file). The app is built from in-repo source with buildPythonApplication.
{pkgs, ...}: let
  py = pkgs.python3Packages;
  mediahub = py.buildPythonApplication {
    pname = "mediahub";
    version = "0.1.0";
    pyproject = true;
    src = ./mediahub;
    build-system = [py.hatchling];
    dependencies = with py; [
      fastapi
      uvicorn
      httpx
      guessit
      jinja2
      python-multipart
    ];
    # Tests run in the dev loop via uv; skip them in the package build.
    doCheck = false;
  };

  # The Transmission done-hook: runs as the `transmission` user, sets the env the
  # filer needs, and execs the mediahub-file binary by store path.
  doneHook = pkgs.writeShellScript "mediahub-done-hook" ''
    export MEDIA_ROOT=/tank/media
    export MEDIAHUB_DB=/var/lib/mediahub/review.db
    export CLAUDE_BIN=${pkgs.claude-code}/bin/claude
    export HOME=/var/lib/transmission/.mediahub-home
    exec ${mediahub}/bin/mediahub-file
  '';
in {
  # Expose the built app + the filer binary system-wide (for the Transmission hook).
  environment.systemPackages = [mediahub];

  users.groups.mediahub = {};
  users.users.mediahub = {
    isSystemUser = true;
    group = "mediahub";
    extraGroups = ["media"]; # read downloads + hardlink into the library
    description = "mediahub web service identity";
  };

  systemd.tmpfiles.rules = [
    # Review DB dir — group `media` so the transmission-run filer can write it too.
    "d /var/lib/mediahub         2775 mediahub media -"
    "d /var/lib/mediahub-secrets 0700 root     root  -"
    "d /var/lib/transmission/.mediahub-home 0750 transmission transmission -"
  ];

  systemd.services.mediahub-web = {
    description = "mediahub search/grab/review web app";
    after = ["network.target" "prowlarr.service"];
    wantedBy = ["multi-user.target"];
    environment = {
      MEDIAHUB_HOST = "127.0.0.1";
      MEDIAHUB_PORT = "8083";
      MEDIA_ROOT = "/tank/media";
      DOWNLOADS_DIR = "/tank/media/downloads";
      MEDIAHUB_DB = "/var/lib/mediahub/review.db";
      PROWLARR_URL = "http://127.0.0.1:9696";
      TRANSMISSION_RPC_URL = "http://127.0.0.1:9091/transmission/rpc";
    };
    serviceConfig = {
      ExecStart = "${mediahub}/bin/mediahub-web";
      User = "mediahub";
      Group = "media";
      UMask = "0002";
      # PROWLARR_API_KEY comes from this root-only env file (created manually later).
      EnvironmentFile = "/var/lib/mediahub-secrets/env";
      ReadWritePaths = ["/tank/media" "/var/lib/mediahub"];
      Restart = "on-failure";
    };
  };

  # Fire the filer on completion. Merges with the Transmission config in
  # hosts/nixos/nixmachine/default.nix.
  services.transmission.settings = {
    script-torrent-done-enabled = true;
    script-torrent-done-filename = "${doneHook}";
  };

  # The hook runs inside transmission.service's sandbox — widen it so the filer can
  # hardlink into the library, write the review DB, run claude, and read its key.
  systemd.services.transmission.serviceConfig = {
    EnvironmentFile = "/var/lib/mediahub-secrets/transmission-env"; # ANTHROPIC_API_KEY
    ReadWritePaths = ["/tank/media" "/var/lib/mediahub"];
  };
}
