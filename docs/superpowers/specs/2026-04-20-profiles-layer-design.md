# Profiles Layer Design

## Summary

Add a `profiles/` directory containing cross-layer module bundles. Each profile is a NixOS module, nix-darwin module, or home-manager module that bundles system-level and home-manager-level imports into a single reusable unit. Host files import one profile and add only host-specific overrides (hostname, hardware, timezone, etc.).

## Motivation

The three macOS hosts (`nixmini`, `nixair`, `nixneo`) are nearly identical — they share the same nix-darwin imports, HM imports, user setup, and system packages. Currently each host file repeats ~50 lines of shared config. A profile eliminates this duplication so that adding a tool to all macOS hosts requires one edit instead of three.

## Profiles

### `profiles/darwin-desktop.nix`

**Type:** nix-darwin module

**Bundles:**
- nix-darwin modules: `fonts`, `homebrew`, `secrets`, `system`
- Home-manager modules: `common`, `darwin/aerospace.nix`, `darwin/karabiner.nix`, `darwin/packages.nix`

**Also sets:**
- `nixpkgs.config.allowUnfree = true`
- `nix.enable = false`
- `programs.fish.enable = true`
- `environment.systemPackages` (git, agenix)
- `nixpkgs.hostPlatform = "aarch64-darwin"`
- User account setup (uid 501, fish shell)
- `home-manager` wiring (useGlobalPkgs, useUserPackages, extraSpecialArgs)
- `system.stateVersion = 6`

**Hosts using this:** nixmini, nixair, nixneo

### `profiles/nixos-desktop.nix`

**Type:** NixOS module

**Bundles:**
- NixOS modules: `boot`, `hardware`, `desktop`, `secrets`
- Home-manager modules: `common`, `linux`

**Also sets:**
- `nixpkgs.config.allowUnfree = true`
- `nix.settings.experimental-features`
- `programs.fish.enable = true`
- `environment.systemPackages` (git, agenix)
- `catppuccin` theming
- `networking.networkmanager.enable = true`
- User account setup (normalUser, wheel + networkmanager groups, fish shell)
- `home-manager` wiring

**Hosts using this:** nixps

### `profiles/server.nix`

**Type:** home-manager module (for standalone HM on non-NixOS servers)

**Bundles:**
- Home-manager modules: `common`, `linux`

**Hosts using this:** chameleon (and future servers)

## Host file structure after

Each host file becomes minimal — just identity and overrides:

```nix
# hosts/macos/nixmini.nix
{...}: {
  imports = [../../profiles/darwin-desktop.nix];
  networking.hostName = "nixmini";
  networking.computerName = "nixmini";
  home-manager.backupFileExtension = "backup";
}
```

```nix
# hosts/nixos/nixps/default.nix
{inputs, pkgs, ...}: {
  imports = [
    ../../../profiles/nixos-desktop.nix
    ./hardware.nix
  ];
  networking.hostName = "nixps";
  time.timeZone = "America/Chicago";
  swapDevices = [{device = "/swapfile"; size = 8192;}];
  environment.systemPackages = with pkgs; [
    wifitui
    banana-cursor
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
  system.stateVersion = "26.05";
}
```

```nix
# hosts/foreign/chameleon/default.nix
{...}: {
  imports = [../../../profiles/server.nix];
  home.username = "cc";
  home.homeDirectory = "/home/cc";
  catppuccin.bottom.enable = false;
}
```

## What does NOT change

- `lib/mk-hosts.nix` — `mkDarwin`, `mkNixos`, `mkHome` helpers stay the same. They still receive host paths; profiles are internal to the host modules.
- `modules/` directory — unchanged. Profiles import from modules; modules remain the atomic units.
- `users/` directory — unchanged.

## Future profiles

- `profiles/nixos-server.nix` — for NAS once it has real hardware config
- Additional server profiles can be created as needed (e.g., `profiles/server-minimal.nix` without the full `common` module set)
