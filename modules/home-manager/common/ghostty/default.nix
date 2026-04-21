{
  pkgs,
  lib,
  osConfig ? {},
  ...
}: {
  programs.ghostty = {
    enable = true;
    package =
      if pkgs.stdenv.isDarwin
      then null
      else pkgs.ghostty;
    settings =
      {
        font-family = "JetBrainsMono Nerd Font";
        font-size = 16;
        window-padding-x = 8;
        window-padding-y = 8;
        cursor-style = "block";
        copy-on-select = true;
        shell-integration-features = "ssh-terminfo";
        background-opacity = 0.9;
        background-blur-radius = 20;
      }
      // lib.optionalAttrs ((osConfig.networking.hostName or "") == "nixmini") {
        custom-shader = [
          "${./shaders/inside-the-matrix.glsl}"
          # "${./shaders/cursor_blaze.glsl}"
        ];
      };
  };
}
