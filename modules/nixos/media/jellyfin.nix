# Jellyfin media server. Reads the library (member of `media`) and transcodes in
# hardware via the VAAPI stack from hardware.graphics (members of render/video).
# openFirewall opens TCP 8096/8920 plus UDP 1900/7359 (client auto-discovery) —
# any-source, per the box-wide firewall simplification.
_: {
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };
  users.users.jellyfin.extraGroups = ["media" "render" "video"];
}
