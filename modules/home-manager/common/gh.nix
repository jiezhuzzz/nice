{pkgs, ...}: let
  user = import ../../../users/jie.nix;
in {
  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-dash
      gh-poi
      gh-eco
      gh-s
      gh-f
    ];
  };
}
