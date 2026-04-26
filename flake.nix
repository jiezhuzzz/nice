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

    # Declarative Homebrew install (complements nix-darwin's `homebrew` state mgmt).
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # Override brew-src to track Homebrew/brew HEAD; nix-homebrew's pin lags
    # behind the homebrew-cask/core taps, causing DSL incompatibilities.
    nix-homebrew.inputs.brew-src.url = "github:Homebrew/brew";

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
        };
        # devShells.default = pkgs.mkShellNoCC {
        #   packages = with pkgs; [
        #     nil
        #     alejandra
        #   ];
        # };
      };
    };
}
