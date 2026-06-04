# Standalone home-manager config for the vegeta compute node.
# Activate with: home-manager switch --flake .#vegeta
{...}: {
  imports = [../../../profiles/server.nix];

  home.username = "jiezzz";
  home.homeDirectory = "/zp_vegeta/scratch_sb/jiezzz";

  catppuccin.bottom.enable = false;
}
