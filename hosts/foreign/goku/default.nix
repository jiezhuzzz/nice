# Standalone home-manager config for the goku compute node.
# Activate with: home-manager switch --flake .#goku
{...}: {
  imports = [../../../profiles/server.nix];

  home.username = "jiezzz";
  home.homeDirectory = "/zp_goku/scratch_sb/jiezzz";

  catppuccin.bottom.enable = false;
}
