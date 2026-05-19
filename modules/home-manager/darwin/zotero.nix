# Sync Zotero settings + extensions across macOS desktops via the rclone
# Dropbox mount. Only prefs.js / extensions / extensions.json are redirected;
# the library DB, storage/, and caches stay on Zotero's own built-in sync.
#
# Mechanism: Zotero profile dirs carry a random hash, so we pin the active
# profile to Profiles/sync.default via an idempotent profiles.ini, then point
# the three syncable items at ~/Dropbox/zotero/ using out-of-store symlinks
# (Zotero must be able to write through them). On a machine whose synced dir
# is still empty, the existing profile is copied in once to seed it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  zoteroRel = "Library/Application Support/Zotero";
  pinnedRel = "${zoteroRel}/Profiles/sync.default";
  syncDir = "${homeDir}/Dropbox/zotero";
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
in {
  home.file."${pinnedRel}/prefs.js".source =
    config.lib.file.mkOutOfStoreSymlink "${syncDir}/prefs.js";
  home.file."${pinnedRel}/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${syncDir}/extensions";
  home.file."${pinnedRel}/extensions.json".source =
    config.lib.file.mkOutOfStoreSymlink "${syncDir}/extensions.json";

  home.activation.zoteroSync = lib.hm.dag.entryAfter ["writeBoundary"] ''
    zoteroBase="${homeDir}/${zoteroRel}"
    syncDir="${syncDir}"
    pinnedDir="$zoteroBase/Profiles/sync.default"

    $DRY_RUN_CMD mkdir -p "$pinnedDir"

    # Pin the profile: write profiles.ini only when the pinned Path is
    # missing, so Zotero's runtime additions ([Install*], Version=) survive.
    # Kept writable (Zotero rewrites it at runtime).
    iniFile="$zoteroBase/profiles.ini"
    if ! grep -qF "Path=Profiles/sync.default" "$iniFile" 2>/dev/null; then
      $DRY_RUN_CMD install -m 0644 ${profilesIni} "$iniFile"
    fi

    # The rest writes under the rclone Dropbox mount. Skip until the FUSE
    # mount is actually up — the rclone-sidecar-wrapper pre-creates
    # ~/Dropbox as an empty local dir before each mount attempt, so a bare
    # [ -d ~/Dropbox ] check is always true; seeding into that local stub
    # makes the mountpoint non-empty and rclone then refuses to mount over
    # it. Detect a real mount by comparing device numbers: a FUSE mount
    # lives on a different filesystem than $HOME. Runs on a later
    # activation once the mount exists.
    dropboxDev=$(stat -f %d "${homeDir}/Dropbox" 2>/dev/null || true)
    homeDev=$(stat -f %d "${homeDir}" 2>/dev/null || true)
    if [ -n "$dropboxDev" ] && [ "$dropboxDev" != "$homeDev" ]; then
      $DRY_RUN_CMD mkdir -p "$syncDir"

      # First-run seed: if the synced dir has no prefs.js yet, copy from the
      # existing (non-pinned) *.default profile so current settings + the
      # dataDir pointer are preserved. Never overwrite an already-synced dir.
      if [ ! -e "$syncDir/prefs.js" ]; then
        src=""
        for d in "$zoteroBase"/Profiles/*.default; do
          [ -d "$d" ] || continue
          if [ "$d" != "$pinnedDir" ]; then src="$d"; break; fi
        done
        if [ -n "$src" ]; then
          [ -f "$src/prefs.js" ] && $DRY_RUN_CMD cp -p "$src/prefs.js" "$syncDir/prefs.js"
          [ -f "$src/extensions.json" ] && $DRY_RUN_CMD cp -p "$src/extensions.json" "$syncDir/extensions.json"
          [ -d "$src/extensions" ] && $DRY_RUN_CMD cp -pR "$src/extensions" "$syncDir/extensions"
        fi
      fi
    fi
  '';
}
