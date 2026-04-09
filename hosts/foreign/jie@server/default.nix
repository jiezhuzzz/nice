# Standalone home-manager config for the Ubuntu server.
# Activate with: home-manager switch --flake .#jie@server
{...}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    ../../../modules/home-manager/common
    ../../../modules/home-manager/linux
  ];

  home.username = user.me.username;
  home.homeDirectory = "/home/${user.me.username}";

  # catppuccin/nix's bottom module uses IFD on a x86_64-linux-only derivation,
  # which breaks `nix flake check` from aarch64-darwin. Server doesn't need it.
  catppuccin.bottom.enable = false;
}
