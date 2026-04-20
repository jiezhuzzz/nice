# Declarative Homebrew for nix-darwin.
#
# Two layers:
#   - nix-homebrew (zhaofengli/nix-homebrew) installs Homebrew itself and
#     pins taps to flake inputs (no mutable taps, no network at activation).
#   - nix-darwin's `homebrew` module manages which casks are installed.
#
# Manages casks and Mac App Store apps.
{inputs, ...}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = false; # Apple Silicon only, no Intel layer
    user = user.me.username;
    autoMigrate = false; # refuse if a non-nix brew install is already present
    mutableTaps = false; # taps come from flake inputs, not `brew tap`
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false; # don't hit network on every darwin-rebuild
      upgrade = true; # upgrade installed casks on activation
      cleanup = "zap"; # remove anything not declared here
    };
    # Keep state-side tap list in sync with nix-homebrew.taps above.
    taps = [
      "homebrew/homebrew-core"
      "homebrew/homebrew-cask"
      "homebrew/homebrew-bundle"
    ];
    brews = [];
    casks = [
      "1password"
      "raycast"
      "betterdisplay"
      "balenaetcher"
      "claude"
      "iina"
      "keka"
      "zen"
      "zoom"
      "squirrel-app"
      "cleanshot"
      "ghostty"
      "karabiner-elements"
      "zed"
      "zotero"
    ];
    masApps = {
      Bitwarden = 1352778147;
      Portal = 1436994560;
      WeChat = 836500024;
      "Pixelmator Pro" = 6746662575;
    };
  };
}
