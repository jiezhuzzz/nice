# Transmission — BitTorrent daemon. Downloads land on the tank pool under the
# media dataset. RPC/web UI has no password; openRPCPort admits 9091 and the
# app-level rpc-whitelist below (127.0.0.1 + LAN) is the real gate. The
# module auto-adds download-dir and incomplete-dir to the
# unit's ReadWritePaths and creates them owned by the `transmission` user, so
# writing under /tank/media needs no chown.
#
# NOTE: /tank/media/{downloads,library} dirs + perms are created by ./storage.nix
# (2775, group `media`). Transmission's download-dir must pre-exist for its
# BindPaths sandbox, and tmpfiles there (ordered before transmission.service)
# provides it.
_: {
  services.transmission = {
    enable = true;
    openFirewall = true; # peer port 51413 (tcp+udp)
    openRPCPort = true; # web UI / RPC 9091 (app-level rpc-whitelist still applies)
    settings = {
      umask = 2; # octal 002 — downloaded files land group-writable (group `media`)
      download-dir = "/tank/media/downloads";
      incomplete-dir = "/tank/media/downloads/.incomplete";
      incomplete-dir-enabled = true;

      rpc-bind-address = "0.0.0.0"; # listen on the LAN, not just loopback
      rpc-port = 9091;
      rpc-authentication-required = false; # trusted-LAN model
      rpc-whitelist-enabled = true;
      # NOTE: direct tailnet access to :9091 (100.x source) is 403'd by this whitelist;
      # remote use goes via transmission.jiezhu.me (caddy proxies from 127.0.0.1).
      rpc-whitelist = "127.0.0.1,192.168.86.*"; # app-level IP restriction
      rpc-host-whitelist-enabled = false; # avoid 403 when hitting the UI by IP
    };
  };

  # Transmission joins the shared media group so *arr apps (also in `media`) can
  # read its finished downloads and hardlink them into the library.
  users.users.transmission.extraGroups = ["media"];
}
