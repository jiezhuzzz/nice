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
      # Transparency. background-blur-radius is macOS-only (frosted glass);
      # Linux ignores it.
      background-opacity = 0.9;
      background-blur-radius = 20;
      # Post-processing shader pipeline (order matters — each shader's output
      # feeds iChannel0 of the next):
      #   1. inside-the-matrix: replaces empty background with matrix rain,
      #      preserves bright pixels as "terminal content".
      #   2. cursor_blaze: draws a cursor trail using iCurrentCursor /
      #      iPreviousCursor / iTimeCursorChange uniforms. Runs last so the
      #      trail is painted on top of the matrix effect.
      custom-shader = [
        "${./ghostty-shaders/inside-the-matrix.glsl}"
        #"${./ghostty-shaders/cursor_blaze.glsl}"
      ];
    };
  };
}
