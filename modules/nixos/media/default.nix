# Media stack for nixmachine: shared storage/permissions, Transmission,
# Jellyfin, and MetaTube. Firewall holes live with each service module.
{...}: {
  imports = [
    ./storage.nix
    ./transmission.nix
    ./jellyfin.nix
    ./metatube.nix
    ./filer.nix
  ];
}
