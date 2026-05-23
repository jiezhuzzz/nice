# rclone remotes + auto-mounts. Cross-platform: home-manager emits systemd
# user services on Linux and launchd agents on macOS.
#
# Token paths differ per platform:
#   - macOS: agenix (nix-darwin) decrypts to /run/agenix/<name>
#   - Linux: chameleon is standalone home-manager (no system agenix);
#     tokens are placed under XDG data dir.
# macOS additionally needs a FUSE provider for mounts (fuse-t cask).
{
  config,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  tokenPath = name:
    if isDarwin
    then "/run/agenix/rclone-${name}-token"
    else "${config.xdg.dataHome}/rclone/${name}-token";
  gdriveTokenPath = tokenPath "gdrive";
  boxTokenPath = tokenPath "box";
  # Drop macOS metadata cruft (AppleDouble shadow files emitted whenever a
  # file with xattrs is written to a non-xattr-supporting FS like fuse-t/NFS,
  # plus Finder's .DS_Store). Bidirectional in mount mode: cruft never
  # reaches the cloud and never appears in the local mount view.
  rcloneFilter = pkgs.writeText "rclone-mount-filter" ''
    - ._*
    - .DS_Store
  '';
  mountOptions = {
    vfs-cache-mode = "writes";
    vfs-cache-max-size = "10G";
    dir-cache-time = "1h";
    umask = "022";
    filter-from = "${rcloneFilter}";
  };
in {
  programs.rclone = {
    enable = true;
    remotes.gdrive = {
      config = {
        type = "drive";
        scope = "drive";
      };
      secrets.token = gdriveTokenPath;
      mounts."" = {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/GDrive";
        options = mountOptions;
      };
    };
    remotes.box = {
      config = {
        type = "box";
      };
      secrets.token = boxTokenPath;
      mounts."" = {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/Box";
        options = mountOptions;
      };
    };
  };
}
