# profiles/server.nix
# Shared home-manager profile for standalone HM on non-NixOS servers.
{...}: {
  imports = [
    ../modules/home-manager/common
    ../modules/home-manager/linux
  ];
}
