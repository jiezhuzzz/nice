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

    catppuccin.url = "github:catppuccin/nix";

    # noctalia-shell: the Quickshell desktop shell for niri on nixps.
    #
    # `follows` keeps a single nixpkgs across the flake, consistent with every
    # other input here. The trade-off is that it also defeats upstream's
    # binary cache — rebuilding against our nixpkgs changes the derivation
    # hashes, so noctalia.cachix.org never matches and Quickshell/Qt are built
    # from source. Drop the follows if that build cost stops being acceptable.
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.darwin.follows = "nix-darwin";

    # Declarative disk partitioning / ZFS layout for the nixmachine NAS.
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Signed boot (UEFI Secure Boot) for nixps; see modules/nixos/secureboot.nix.
    #
    # Pinned past v1.1.0 to an explicit master rev, not a branch: only master
    # has autoEnrollKeys.includeFirmwareBuiltinKeys, which this Dell needs to
    # retain its OEM certificates through enrollment so fwupd firmware updates
    # keep working. An exact rev keeps `nix flake update` from silently moving
    # unreleased code in the boot path. Move back to a tag once one ships with
    # that option.
    lanzaboote.url = "github:nix-community/lanzaboote/6183ac79eadb079a1e72fa2c60915601be669100";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative Homebrew install (complements nix-darwin's `homebrew` state mgmt).
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # brew-src follows nix-homebrew's own default. It was previously pinned to
    # brew 28d1032 to dodge a symlinked-taps regression (casks rejected as "not
    # in a tap"); nix-homebrew fixed that in PR #150 and now defaults to brew
    # 6.x, so the override is gone. Re-pin here only if the default regresses.

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
