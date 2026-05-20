# Sync Zotero settings + extensions across macOS desktops via the rclone
# Dropbox mount. Only the config layer is synced (no library DB, no caches);
# the library DB and storage/ stay on Zotero's own built-in sync.
#
# Mechanism: Zotero profile dirs carry a random hash, so we pin the active
# profile to Profiles/sync.default via an idempotent profiles.ini, then make
# the WHOLE pinned profile directory an out-of-store symlink to
# ~/Dropbox/Apps/Zotero/. Atomic-rename writes (Mozilla apps' safe-save
# pattern) now happen INSIDE the synced directory rather than overwriting
# our symlink — the dir-level symlink lives one level above where renames
# happen, so it cannot be replaced by an inner rewrite.
#
# Per-machine state that must not propagate (lock files, SQLite WAL/journal,
# caches, sessionstore, credentials, telemetry) is filtered out at the
# rclone mount layer (see common/rclone.nix's filter-from). Those files
# still get written locally via rclone's VFS cache, just never uploaded.
#
# Migration: an activation script (entryBefore writeBoundary) handles the
# transition from an existing real sync.default/ directory (either left over
# from the previous per-file design, or the user's original random-hash
# profile) by copying whitelisted items into the synced dir on first run.
{
  config,
  lib,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  zoteroRel = "Library/Application Support/Zotero";
  pinnedRel = "${zoteroRel}/Profiles/sync.default";
  syncDir = "${homeDir}/Dropbox/Apps/Zotero";
  profilesIni = pkgs.writeText "zotero-profiles.ini" ''
    [Profile0]
    Name=default
    IsRelative=1
    Path=Profiles/sync.default
    Default=1

    [General]
    StartWithLastProfile=1
    Version=2
  '';
  # Files inside the Zotero profile that are safe to share across machines.
  # Kept in sync with the include-list in common/rclone.nix's filter-from.
  syncWhitelist = [
    "prefs.js"
    "extensions"
    "extensions.json"
    "extensions.json.backup"
    "xulstore.json"
    "treePrefs.json"
    "handlers.json"
    "retractions.json"
  ];
in {
  home.file."${pinnedRel}".source =
    config.lib.file.mkOutOfStoreSymlink "${syncDir}";

  # Pre-link migration: if sync.default is currently a real directory
  # (transitioning from the per-file design, or a fresh machine with the
  # user's pre-existing random-hash *.default profile), copy whitelisted
  # items into the synced Dropbox dir, then remove the real dir so
  # home-manager can place its directory symlink. Skipped when the Dropbox
  # mount isn't up (rclone-sidecar-wrapper's pre-created local stub is
  # detected by comparing device numbers).
  home.activation.zoteroMigrate = lib.hm.dag.entryBefore ["writeBoundary"] ''
    zoteroBase="${homeDir}/${zoteroRel}"
    syncDir="${syncDir}"
    pinnedDir="$zoteroBase/Profiles/sync.default"

    dropboxDev=$(stat -f %d "${homeDir}/Dropbox" 2>/dev/null || true)
    homeDev=$(stat -f %d "${homeDir}" 2>/dev/null || true)
    if [ -z "$dropboxDev" ] || [ "$dropboxDev" = "$homeDev" ]; then
      exit 0   # Dropbox not really mounted; defer migration to a later switch
    fi

    $DRY_RUN_CMD mkdir -p "$syncDir"

    copy_whitelist() {
      local src="$1"
      ${lib.concatMapStringsSep "\n      " (item: ''
      if [ -e "$src/${item}" ] && [ ! -e "$syncDir/${item}" ]; then
        $DRY_RUN_CMD cp -pR "$src/${item}" "$syncDir/${item}"
      fi'')
    syncWhitelist}
    }

    # Case A: pinnedDir is a real directory — migrate its content, then remove.
    if [ -d "$pinnedDir" ] && [ ! -L "$pinnedDir" ]; then
      copy_whitelist "$pinnedDir"
      $DRY_RUN_CMD rm -rf "$pinnedDir"
    fi

    # Case B: still nothing in syncDir — seed from another *.default profile
    # (the user's original random-hash profile on a fresh machine).
    if [ ! -e "$syncDir/prefs.js" ]; then
      for d in "$zoteroBase"/Profiles/*.default; do
        [ -d "$d" ] || continue
        [ "$d" = "$pinnedDir" ] && continue
        copy_whitelist "$d"
        break
      done
    fi
  '';

  # Post-link activation: pin profiles.ini idempotently. Lives at the Zotero
  # base (not inside the symlinked profile dir), so unaffected by the dir
  # symlink. Writes only when the pin marker is absent so Zotero's runtime
  # additions ([Install*], Version=) survive.
  home.activation.zoteroProfile = lib.hm.dag.entryAfter ["writeBoundary"] ''
    iniFile="${homeDir}/${zoteroRel}/profiles.ini"
    if ! grep -qF "Path=Profiles/sync.default" "$iniFile" 2>/dev/null; then
      $DRY_RUN_CMD install -m 0644 ${profilesIni} "$iniFile"
    fi
  '';
}
