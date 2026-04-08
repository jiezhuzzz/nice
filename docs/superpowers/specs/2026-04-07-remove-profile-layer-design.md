# Remove Profile Layer

**Date:** 2026-04-07
**Status:** Approved

## Summary

Remove the `profiles/` directory and inline its contents directly into each consuming host. The profile layer currently adds indirection without enough value — each profile is thin and consumed by exactly one host.

## Changes

### `hosts/nixos/naptop/default.nix`

Replace `../../../profiles/workstation.nix` import with:

- Direct imports: `modules/nixos/boot`, `modules/nixos/hardware`, `modules/nixos/desktop`
- Inline config:
  - `nixpkgs.config.allowUnfree = true`
  - `nix.settings.experimental-features = ["nix-command" "flakes"]`
  - `programs.fish.enable = true`
  - `environment.systemPackages`: wifitui, git, banana-cursor, zen-browser, agenix

### `hosts/macos/macmini/default.nix`

Replace `../../../profiles/darwin.nix` import with:

- Direct imports: `modules/nix-darwin/homebrew`, `modules/nix-darwin/system`
- Inline config:
  - `nixpkgs.config.allowUnfree = true`
  - `nix.settings.experimental-features = ["nix-command" "flakes"]`
  - `programs.fish.enable = true`
  - `environment.systemPackages`: git, agenix

### `hosts/nixos/nas/default.nix`

Replace `../../../profiles/nas.nix` import with:

- Inline config:
  - `nixpkgs.config.allowUnfree = true`
  - `nix.settings.experimental-features = ["nix-command" "flakes"]`

### Delete

- `profiles/darwin.nix`
- `profiles/workstation.nix`
- `profiles/server.nix`
- `profiles/nas.nix`

## Not changed

- `lib/mk-hosts.nix` — no profile references
- All modules under `modules/` — untouched
- `users/jie.nix` — untouched
- `hosts/foreign/jie@server/` — never used profiles

## Verification

- `nix flake check` should pass (evaluates all configurations)
