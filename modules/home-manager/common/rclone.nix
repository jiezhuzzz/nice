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
  dropboxTokenPath = tokenPath "dropbox";
  # Drop macOS metadata cruft (AppleDouble shadow files emitted whenever a
  # file with xattrs is written to a non-xattr-supporting FS like fuse-t/NFS,
  # plus Finder's .DS_Store). Bidirectional in mount mode: cruft never
  # reaches the cloud and never appears in the local mount view.
  #
  # The Zotero block is an include-list scoped to /Apps/Zotero/: explicit
  # files sync; everything else under that path is local-only (the rclone
  # VFS cache holds it but it never propagates). This keeps the dir-level
  # symlink used by modules/home-manager/darwin/zotero.nix safe — Zotero
  # creates lock files, SQLite WALs, caches, sessionstore, etc. inside the
  # synced dir, but only the curated whitelist reaches the cloud and other
  # machines. Kept in sync with that module's `syncWhitelist`.
  rcloneFilter = pkgs.writeText "rclone-mount-filter" ''
    - ._*
    - .DS_Store
    + /Apps/Zotero/prefs.js
    + /Apps/Zotero/extensions/**
    + /Apps/Zotero/extensions.json
    + /Apps/Zotero/extensions.json.backup
    + /Apps/Zotero/xulstore.json
    + /Apps/Zotero/treePrefs.json
    + /Apps/Zotero/handlers.json
    + /Apps/Zotero/retractions.json
    - /Apps/Zotero/**
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
    remotes.dropbox = {
      config = {
        type = "dropbox";
      };
      secrets.token = dropboxTokenPath;
      mounts."" = {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/Dropbox";
        options = mountOptions;
      };
    };
  };
}
