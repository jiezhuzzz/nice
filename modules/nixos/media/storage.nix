# Shared storage + permissions for the media stack. Every service runs as its
# own user but must share files so MoviePilot can hardlink Transmission's
# downloads into the library. A shared `media` group + setgid 2775 dirs + a
# group-writable umask (set per-service) makes that work.
_: {
  users.groups.media = {};

  # Library + download layout on the single tank/media ZFS dataset — one dataset
  # means imports are hardlinks (one copy on disk) and moves are atomic.
  # 2775 = setgid, so files/dirs created inside inherit group `media`. Library
  # roots are root:media (MoviePilot writes inside them via group-write, it need
  # not own the root); download dirs are transmission:media.
  systemd.tmpfiles.rules = [
    "d /tank/media                       2775 root         media -"
    "d /tank/media/downloads             2775 transmission media -"
    "d /tank/media/downloads/.incomplete 2775 transmission media -"
    "d /tank/media/movies                2775 root         media -"
    "d /tank/media/tv                    2775 root         media -"
    "d /tank/media/anime                 2775 root         media -"
    "d /tank/media/music                 2775 root         media -"
    "d /tank/media/xxx                   2775 root         media -"
  ];
}
