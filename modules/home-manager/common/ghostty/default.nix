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
        font-family = [
          "JetBrainsMono Nerd Font"
          "Noto Sans Mono CJK SC"
        ];
        font-size = 16;
        window-padding-x = 8;
        window-padding-y = 8;
        cursor-style = "block";
        copy-on-select = true;
        # Make alt+backspace send the classic "meta-DEL" byte pair — ESC (\x1b)
        # then DEL (\x7f) — which readline, fish, zsh and pi's editor all read
        # as delete-word-backward. Recommended by pi's terminal-setup docs
        # (libexec/pi/docs/terminal-setup.md); pi otherwise doesn't see the
        # chord under Ghostty.
        #
        # Ghostty's `text:` action parses a Zig string literal, so the \x
        # escapes must reach the config file verbatim and be decoded there, not
        # by Nix — hence the '' string, in which a lone backslash is literal.
        #
        # This is a global binding, and a `text:` action bypasses the Kitty
        # keyboard protocol for this one chord: every program in the terminal
        # now sees ESC+DEL instead of a structured alt+backspace key event.
        # That is what shell line editors want anyway.
        keybind = [
          ''alt+backspace=text:\x1b\x7f''
        ];
        shell-integration-features = "ssh-terminfo";
        background-opacity = 0.9;
        background-blur-radius = 20;
      }
      // lib.optionalAttrs ((osConfig.networking.hostName or "") == "nixmini") {
        custom-shader = [
          "${./shaders/inside-the-matrix.glsl}"
          "${./shaders/cursor_blaze.glsl}"
        ];
      };
  };
}
