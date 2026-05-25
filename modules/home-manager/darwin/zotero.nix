# Sync Zotero settings + extensions across macOS desktops via the native
# Dropbox client. Only the config layer is synced (no library DB, no caches);
# the library DB and storage/ stay on Zotero's own built-in sync.
#
# Mechanism: Zotero profile dirs carry a random hash, so we pin the active
# profile to Profiles/sync.default via an idempotent profiles.ini, then make
# the WHOLE pinned profile directory an out-of-store symlink to
# ~/Library/CloudStorage/Dropbox/Apps/Zotero/ (macOS 12.3+ moved Dropbox to
# the file-provider extension; the legacy ~/Dropbox path is no longer
# created). Atomic-rename writes (Mozilla apps' safe-save
# pattern) now happen INSIDE the synced directory rather than overwriting
# our symlink — the dir-level symlink lives one level above where renames
# happen, so it cannot be replaced by an inner rewrite.
#
# Per-machine state that must not propagate (lock files, SQLite WAL/journal,
# caches, sessionstore, telemetry) is filtered out by tagging the relevant
# paths with Dropbox's com.dropbox.ignored xattr (see zoteroDropboxIgnore
# activation below). Native Dropbox has no rclone-style include-list, so we
# enumerate known-noisy paths instead. Re-runs every switch; files born and
# deleted between switches sync briefly — acceptable for the
# single-active-machine workflow this assumes.
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
  dropboxRoot = "${homeDir}/Library/CloudStorage/Dropbox";
  syncDir = "${dropboxRoot}/Apps/Zotero";
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
  # Used by the migration script below to seed the synced dir from an
  # existing random-hash profile on first run.
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
  # CloudStorage dir is missing or empty — Dropbox isn't set up here yet,
  # so defer to a later switch.
  home.activation.zoteroMigrate = lib.hm.dag.entryBefore ["writeBoundary"] ''
    zoteroBase="${homeDir}/${zoteroRel}"
    syncDir="${syncDir}"
    pinnedDir="$zoteroBase/Profiles/sync.default"

    if [ ! -d "${dropboxRoot}" ] || [ -z "$(ls -A "${dropboxRoot}" 2>/dev/null)" ]; then
      exit 0   # Dropbox not yet initialized; defer migration to a later switch
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

  # Tag per-machine state inside the synced profile with com.dropbox.ignored
  # so Dropbox skips it. Runs every switch — files Zotero has created since
  # the last activation get tagged now; files born and deleted between
  # switches sync briefly. Extend the list when new noisy paths show up.
  home.activation.zoteroDropboxIgnore = lib.hm.dag.entryAfter ["writeBoundary"] ''
    syncDir="${syncDir}"
    [ -d "$syncDir" ] || exit 0

    tag() {
      if [ -e "$1" ]; then
        $DRY_RUN_CMD /usr/bin/xattr -w com.dropbox.ignored 1 "$1" 2>/dev/null || true
      fi
    }

    for p in parent.lock cache cache2 startupCache compatibility.ini \
             times.json sessionstore.js sessionstore-backups crashes \
             minidumps datareporting safebrowsing safebrowsing-cache \
             thumbnails storage permissions.sqlite webappsstore.sqlite \
             pluginsdb.sqlite; do
      tag "$syncDir/$p"
    done

    for p in "$syncDir"/*.sqlite-wal "$syncDir"/*.sqlite-journal "$syncDir"/*.sqlite-shm; do
      tag "$p"
    done
  '';
}
