# Transmission — BitTorrent daemon. Downloads land on the tank pool under the
# media dataset. RPC/web UI has no password; openRPCPort admits 9091 and the
# app-level rpc-whitelist below (127.0.0.1 + LAN) is the real gate. The NixOS
# module's setup unit creates download-dir and incomplete-dir before the daemon
# starts; using `media` as its primary group keeps both directories shared.
_: {
  services.transmission = {
    enable = true;
    group = "media";
    downloadDirPermissions = "2775";
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
}
