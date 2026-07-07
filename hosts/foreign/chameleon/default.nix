# Standalone home-manager config for the Chameleon Cloud server.
# Activate with: home-manager switch --flake .#chameleon
{...}: {
  imports = [../../../profiles/home/server.nix];

  home.username = "cc";
  home.homeDirectory = "/home/cc";

  catppuccin.bottom.enable = false;
}
