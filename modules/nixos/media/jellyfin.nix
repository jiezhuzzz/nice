# Jellyfin media server. Reads the library (member of `media`) and transcodes in
# hardware via the VAAPI stack from hardware.graphics (members of render/video).
# Firewall is handled centrally in firewall.nix (LAN-restricted), so the module's
# own openFirewall stays off.
_: {
  services.jellyfin = {
    enable = true;
    openFirewall = false;
  };
  users.users.jellyfin.extraGroups = ["media" "render" "video"];
}
