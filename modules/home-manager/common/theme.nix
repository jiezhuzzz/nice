_: let
  user = import ../../../users/jie.nix;
in {
  catppuccin.enable = true;
  catppuccin.autoEnable = true;
  catppuccin.flavor = user.theme.flavor;
}
