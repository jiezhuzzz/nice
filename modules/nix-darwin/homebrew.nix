# Declarative Homebrew for nix-darwin.
#
# Two layers:
#   - nix-homebrew (zhaofengli/nix-homebrew) installs Homebrew itself and
#     pins taps to flake inputs (no mutable taps, no network at activation).
#   - nix-darwin's `homebrew` module manages which casks are installed.
#
# Manages casks and Mac App Store apps.
{
  inputs,
  user,
  ...
}: {
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
      # Homebrew 4.x added a confirmation gate on `brew bundle install --cleanup`;
      # unattended activation must opt in via --force-cleanup (or --force / $HOMEBREW_ASK).
      extraFlags = ["--force-cleanup"];
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
      "affinity"
      "balenaetcher"
      "betterdisplay"
      "claude"
      "cleanshot"
      "drawio"
      "dropbox"
      "figma"
      "fuse-t"
      "ghostty"
      "iina"
      "karabiner-elements"
      "keka"
      "pdf-expert"
      "raycast"
      "skim"
      "squirrel-app"
      "stats"
      "tailscale-app"
      "thebrowsercompany-dia"
      "tor-browser"
      "ungoogled-chromium"
      "zoom"
      "zotero"
    ];
    masApps = {
      Amphetamine = 937984704;
      Bitwarden = 1352778147;
      "Pixelmator Pro" = 6746662575;
      Portal = 1436994560;
      WeChat = 836500024;
    };
  };
}
