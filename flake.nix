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
    xremap-flake = {
      url = "github:xremap/nix-flake";
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

    # noctalia-greeter: the greetd login screen matching noctalia-shell, used on
    # nixps (see modules/nixos/desktop/login.nix).
    #
    # `follows` for the same reason as `noctalia` above, and with the same
    # trade-off: it defeats the project's own binary cache, so the bundled
    # wlroots compositor is built from source against our nixpkgs. That build is
    # far cheaper than noctalia's Qt/Quickshell closure, so it is accepted here
    # rather than carrying a second nixpkgs to keep the cache match.
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # llm-agents.nix: source for the claude-code and codex CLIs, which upstream
    # tracks faster than nixpkgs (see modules/home-manager/common/{claude-code,
    # codex}.nix). Both are pulled from its `packages.<system>` output.
    #
    # `follows` for consistency with every other input. The trade-off is muted
    # here: claude-code is a prebuilt per-platform binary (a fixed-output fetch,
    # so following costs only its tiny wrapper), and codex is rebuilt from source
    # regardless because we patch it — so numtide's binary cache would miss it
    # even without the follows. A single nixpkgs is the better default.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Catppuccin themes for pi — catppuccin/nix ships no pi module, so
    # catppuccin.autoEnable cannot reach it (see the theme note in
    # modules/home-manager/common/pi.nix).
    #
    # Only `packages.<system>.default` is consumed: a trivial derivation that
    # copies four theme JSONs into share/pi/themes. Upstream's
    # homeManagerModules.default is deliberately NOT imported — it hardcodes
    # ~/.pi/agent/themes (pi runs with an XDG configDir here) and jq-rewrites
    # settings.json in an activation script, which would fight the read-only
    # store symlink home-manager generates from `settings`.
    pi-catppuccin = {
      url = "github:otahontas/pi-coding-agent-catppuccin";
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
    # Track Homebrew/brew HEAD instead of nix-homebrew's own brew-src pin: the
    # tap inputs below follow HEAD (CI bumps flake.lock), so a lagging brew
    # eventually fails to parse casks that use newer DSL. That happened with
    # nix-homebrew's brew 6.0.12 pin vs. betterdisplay's `command_wrapper`
    # (added in brew 6.0.13). Tracking HEAD keeps brew and the taps in step.
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
