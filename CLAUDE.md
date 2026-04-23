# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

NICE (Nix Configures Everything) — a declarative Nix flake managing NixOS and macOS (nix-darwin) systems with home-manager. Single user (`jie`), multiple hosts.

## Common Commands

```bash
# Format all Nix files
nix fmt

# Check flake validity
nix flake check

# Build and switch (macOS)
darwin-rebuild switch --flake .

# Build and switch (NixOS)
sudo nixos-rebuild switch --flake .

# Build and switch (standalone home-manager, e.g. chameleon)
home-manager switch --flake .

# Enter dev shell (nil LSP + alejandra formatter)
nix develop
```

## Architecture

### Host Definitions

Hosts are declared in `flake.nix` via `lib/mk-hosts.nix`:

| Host | Platform | Type |
|------|----------|------|
| `nixps`, `nas` | x86_64-linux | NixOS |
| `nixair`, `nixmini`, `nixneo` | aarch64-darwin | nix-darwin |
| `chameleon` | x86_64-linux | standalone home-manager (remote server) |

Each host has a directory under `hosts/<name>/` with hardware config and host-specific overrides.

### Three-Tier Module System

1. **Profiles** (`profiles/`) — role-based compositions that import modules:
   - `darwin-desktop.nix` — macOS desktop (user setup, home-manager, SSH identity)
   - `nixos-desktop.nix` — Linux desktop (same, with systemd)
   - `server.nix` — lean remote-server profile, home-manager only

2. **Modules** (`modules/`) — individual tool/service configs:
   - `home-manager/common/` — cross-platform tools (git, fish, helix, claude-code, etc.)
   - `home-manager/darwin/` — macOS-specific (aerospace, karabiner)
   - `home-manager/linux/` — Linux-specific (niri, ghostty, shpool)
   - `nixos/` — NixOS system modules (boot, hardware, desktop, secrets)
   - `nix-darwin/` — macOS system modules (fonts, homebrew, secrets, system)

3. **Hosts** (`hosts/`) — per-machine hardware and overrides

### Secrets Management

Uses **agenix** with age-encrypted `.age` files in `secrets/`. Recipient keys declared in `secrets/secrets.nix`. Secrets decrypt to `/run/agenix/` at activation.

### Homebrew (macOS)

Declarative via nix-homebrew + nix-darwin. Taps are immutable (from flake inputs). Casks and App Store apps managed in `modules/nix-darwin/homebrew/`.

## Key Conventions

- **Formatter**: alejandra (not nixfmt or nixpkgs-fmt)
- **Theme**: Catppuccin `frappe` flavor, applied globally via the catppuccin flake input
- **Flake structure**: uses `flake-parts` for modular outputs
- **Python**: always use `uv`, never direct `python`/`pip` — enforced in claude-code settings
