{
  description = "A nice configuration (laptop, mac, server, nas)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    xremap-flake.url = "github:xremap/nix-flake";
    xremap-flake.inputs.nixpkgs.follows = "nixpkgs";

    niri-flake.url = "github:sodiboo/niri-flake";
    niri-flake.inputs.nixpkgs.follows = "nixpkgs";
    niri-flake.inputs.nixpkgs-stable.follows = "nixpkgs";

    catppuccin.url = "github:catppuccin/nix";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.darwin.follows = "nix-darwin";

    # Declarative disk partitioning / ZFS layout for the nixmachine NAS.
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative Homebrew install (complements nix-darwin's `homebrew` state mgmt).
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # Override brew-src (nix-homebrew's own pin lags behind the homebrew-cask/
    # core taps, causing DSL incompatibilities) — but PIN it instead of tracking
    # HEAD. Homebrew commit f0858cca0 ("utils/path: trust symlinked cellar
    # roots") wrapped the allowed Taps root in `.realpath`. With mutableTaps =
    # false, nix-homebrew points /opt/homebrew/Library/Taps at a `taps-env`
    # store path while each tap symlinks to its own per-tap source store path,
    # so the realpath'd root no longer prefix-matches the casks and
    # `brew bundle` rejects every cask ("Homebrew requires casks to be in a
    # tap"). 28d1032 is the last rev before that change; bump past it only once
    # upstream fixes the regression (HEAD still carries it as of 2026-06).
    nix-homebrew.inputs.brew-src.url = "github:Homebrew/brew/28d1032df297777442cf84e97af72c87d3d98ac3";

    # Brew taps pinned via flake.lock (mutableTaps = false).
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      imports = [
        ./lib/mk-hosts.nix
        inputs.treefmt-nix.flakeModule
      ];
      perSystem = {pkgs, ...}: {
        treefmt = {
          projectRootFile = "flake.nix";
          programs.alejandra.enable = true;
          programs.statix.enable = true;
          programs.mdsh.enable = true;
          programs.shellcheck.enable = true;
          programs.shfmt.enable = true;
          programs.actionlint.enable = true;
        };
        devShells.default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            nil
            alejandra
          ];
        };
      };
    };
}
