# Media stack for nixmachine: shared storage/permissions, Transmission,
# Jellyfin, MetaTube, and the LAN-only firewall rules that front them.
{...}: {
  imports = [
    ./storage.nix
    ./transmission.nix
    ./jellyfin.nix
    ./metatube.nix
    ./firewall.nix
  ];
}
