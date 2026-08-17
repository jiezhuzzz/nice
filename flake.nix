{
  description = "A nice configuration (laptop, mac, server, nas)";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        darwin.follows = "nix-darwin";
      };
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned to a master rev, not a tag: only master has
    # autoEnrollKeys.includeFirmwareBuiltinKeys, which nixps needs to keep its
    # OEM certificates (and thus fwupd) working through key enrollment. Move
    # back to a tag once one ships with that option.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/6183ac79eadb079a1e72fa2c60915601be669100";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    xremap-flake = {
      url = "github:xremap/nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Linux desktop: niri shell + matching greetd login screen on nixps.
    # `follows` keeps one nixpkgs flake-wide but defeats upstream's binary
    # cache, so Quickshell/Qt and the greeter's wlroots build from source.
    # Drop the follows if that build cost stops being acceptable.
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      # Track brew HEAD instead of nix-homebrew's brew-src pin: the taps below
      # follow HEAD, so a lagging brew fails to parse casks using newer DSL.
      inputs.brew-src.url = "github:Homebrew/brew";
    };

    # Taps pinned via flake.lock (mutableTaps = false).
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

    catppuccin = {
      url = "github:catppuccin/nix";
    };

    # Only `packages.<system>.default` is consumed. Do NOT import upstream's
    # homeManagerModules.default: it hardcodes ~/.pi/agent/themes and rewrites
    # settings.json, fighting the read-only store symlink home-manager
    # generates from `settings` (see modules/home-manager/common/pi.nix).
    pi-catppuccin = {
      url = "github:otahontas/pi-coding-agent-catppuccin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

    # Source for individual skills, not the plugin: only the subdirectories
    # named in modules/home-manager/common/claude-code/plugins.nix are linked.
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    # Homelab services with no nixpkgs package — the flake carries the build
    # and the NixOS module (see modules/nixos/xuewen.nix).
    xuewen = {
      url = "github:jiezhuzzz/xuewen";
      inputs.nixpkgs.follows = "nixpkgs";
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
