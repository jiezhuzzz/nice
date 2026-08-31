{
  pkgs,
  lib,
  osConfig ? {},
  ...
}: {
  programs.rio = {
    enable = true;
    settings =
      {
        fonts = {
          size = 16;
          family = "JetBrainsMono Nerd Font";
          # Rio takes a single family, not Ghostty's ordered fallback list, so
          # the CJK face has to be pinned per codepoint range instead.
          symbol-map = [
            {
              start = "2E80";
              end = "9FFF";
              font-family = "Noto Sans Mono CJK SC";
            }
            {
              start = "FF00";
              end = "FFEF";
              font-family = "Noto Sans Mono CJK SC";
            }
          ];
        };
        colors.tabs = lib.mkForce "#a5adce";
        # CSS shorthand: [vertical horizontal].
        margin = [8 8];
        cursor.shape = "block";
        copy-on-select = true;
        window = {
          opacity = 0.9;
          opacity-cells = true;
          blur =
            if pkgs.stdenv.hostPlatform.isDarwin
            then "macos-glass-clear"
            else true;
        };
        # Make alt+backspace send the classic "meta-DEL" byte pair — ESC
        # (\x1b) then DEL (\x7f) — which readline, fish, zsh and pi's editor
        # all read as delete-word-backward. Recommended by pi's terminal-setup
        # docs (libexec/pi/docs/terminal-setup.md); Rio's own default for this
        # chord drops out once a program turns on the Kitty keyboard protocol.
        #
        # Nix has no \x escape, so the two bytes come in through JSON.
        bindings.keys = [
          {
            key = "backspace";
            "with" = "alt";
            esc = builtins.fromJSON "\"\\u001b\\u007f\"";
          }
        ];
      }
      // lib.optionalAttrs ((osConfig.networking.hostName or "") == "nixmini") {
        # Rio has no custom-shader hook, so nixmini's Ghostty cursor_blaze
        # becomes the built-in trail; the matrix background has no counterpart.
        effects.trail-cursor = true;
      };
  };
}
