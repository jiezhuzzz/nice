# *arr acquisition/organization apps. Prowlarr only manages indexers over HTTP,
# so it needs no filesystem access (it also runs as a DynamicUser). The rest are
# static users that read Transmission's downloads and hardlink into the library,
# so they join the `media` group and get a group-writable umask.
{lib, ...}: {
  services.prowlarr.enable = true; # DynamicUser; no media access needed
  services.radarr.enable = true; # movies (7878)
  services.sonarr.enable = true; # TV + anime (8989)
  services.bazarr.enable = true; # subtitles (6767)

  users.users.radarr.extraGroups = ["media"];
  users.users.sonarr.extraGroups = ["media"];
  users.users.bazarr.extraGroups = ["media"];

  # Group-writable umask so imported files are 0664 / dirs 0775 → hardlinkable.
  # radarr/sonarr modules set UMask = "0022"; the rest inherit systemd's default
  # 0022. lib.mkForce forces 0002 uniformly (required to override radarr/sonarr).
  systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.bazarr.serviceConfig.UMask = lib.mkForce "0002";
}
