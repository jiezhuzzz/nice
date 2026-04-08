{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package =
      if pkgs.stdenv.isDarwin
      then null
      else pkgs.ghostty;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 14;
      window-padding-x = 8;
      window-padding-y = 8;
      cursor-style = "block";
      copy-on-select = true;
    };
  };
}
