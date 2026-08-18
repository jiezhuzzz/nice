# podman-tui connection map. The package itself is in nixmachine's
# environment.systemPackages next to skopeo, as host tooling; only this
# per-user file belongs to jie.
#
# Every container on this box is a rootful virtualisation.oci-containers unit,
# so the connection has to be the system socket. podman-tui otherwise defaults
# to the rootless socket under $XDG_RUNTIME_DIR (config/utils.LocalNodeUnixSocket)
# and shows an empty host — it reads no CONTAINER_HOST and no containers.conf,
# only this file. Reaching /run/podman/podman.sock also needs jie in the
# `podman` group, its SocketGroup, granted in hosts/nixos/nixmachine/default.nix.
#
# Declared rather than left to first run, which costs the UI's connection
# editor: podman-tui rewrites this file when a connection is added, removed or
# made default, and that write fails against a read-only store symlink.
{pkgs, ...}: let
  jsonFormat = pkgs.formats.json {};
in {
  xdg.configFile."podman-tui/podman-tui.json".source = jsonFormat.generate "podman-tui.json" {
    connections.localhost = {
      uri = "unix:///run/podman/podman.sock";
      default = true;
    };
  };
}
