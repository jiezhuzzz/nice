# MetaTube metadata server for adult content (JAV + Western), consumed by the
# Jellyfin MetaTube plugin. Not packaged in nixpkgs, so it runs as an OCI
# container on the host's podman backend (enabled in nixmachine/default.nix).
# The scraper engine + SQLite DB persist under /var/lib/metatube; a bare-path
# `-dsn` selects SQLite and `-db-auto-migrate` creates/upgrades the schema on
# start (idempotent). Published to 127.0.0.1 only — Jellyfin runs on this host
# and reaches it at localhost:8080 — so no firewall hole is needed for 8080.
#
# Image is pinned by digest for reproducibility; bump it deliberately (pull the
# tag, then `podman inspect --format '{{index .RepoDigests 0}}'`).
_: {
  virtualisation.oci-containers = {
    backend = "podman";
    containers.metatube = {
      image = "ghcr.io/metatube-community/metatube-server@sha256:04d58879b76624e180cfdb24cde042b657189eabd3bd4cba851f1d56f7a5be82";
      ports = ["127.0.0.1:8080:8080"];
      volumes = ["/var/lib/metatube:/config"];
      cmd = [
        "-bind"
        "0.0.0.0" # all interfaces *inside* the netns; the host only publishes to 127.0.0.1
        "-port"
        "8080"
        "-dsn"
        "/config/metatube.db" # bare path → SQLite
        "-db-auto-migrate" # idempotent schema create/upgrade on boot
      ];
    };
  };

  # SQLite DB + engine cache live here. The generated container unit runs as
  # root, so StateDirectory creates /var/lib/metatube as persistent root-owned
  # storage before Podman resolves the bind mount.
  systemd.services.podman-metatube.serviceConfig = {
    StateDirectory = "metatube";
    StateDirectoryMode = "0750";
  };
}
