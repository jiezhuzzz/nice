_: {
  # herdr: a terminal multiplexer (Rust). Enabled on every host via
  # profiles/home/core.nix. Left at defaults for now; settings would go under
  # programs.herdr.settings, which is written to ~/.config/herdr/config.toml.
  programs.herdr.enable = true;
}
