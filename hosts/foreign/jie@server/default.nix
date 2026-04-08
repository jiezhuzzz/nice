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
}
