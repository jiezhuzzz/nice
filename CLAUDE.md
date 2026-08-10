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
| `nixps`, `nixmachine` | x86_64-linux | NixOS |
| `nixair`, `nixmini`, `nixneo` | aarch64-darwin | nix-darwin |
| `chameleon`, `goku`, `vegeta` | x86_64-linux | standalone home-manager (remote servers) |

Each host has a directory under `hosts/<name>/` with hardware config and host-specific overrides.

The `mk-hosts.nix` builders own all cross-cutting plumbing: they inject `inputs` and `user` (from `users/jie.nix`) into every layer's specialArgs, wire home-manager into the system builders (`useGlobalPkgs`, `useUserPackages`, `sharedModules`), and set `allowUnfree` (plus flakes `experimental-features` on NixOS). Profiles and hosts never repeat this.

### Three-Tier Module System

1. **Profiles** (`profiles/`) — role-based compositions that import modules:
   - `darwin-desktop.nix` / `nixos-desktop.nix` — system-side desktop profiles (platform-specific system config + pointing home-manager at the desktop bundle)
   - `homelab.nix` — headless NixOS wrapper that gives `jie` the server bundle
   - `home/core.nix` — CLI toolkit + home settings shared by every machine
   - `home/desktop.nix` — core + GUI/desktop tools + SSH identity pinning
   - `home/server.nix` — core + headless shell tooling (bash, tmux, shpool)

2. **Modules** (`modules/`) — individual tool/service configs:
   - `home-manager/common/` — cross-platform tools (git, fish, helix, claude-code, etc.)
   - `home-manager/darwin/` — macOS-specific (aerospace, karabiner)
   - `home-manager/linux/` — Linux-specific (niri, ghostty, shpool)
   - `nixos/` — NixOS system modules (boot, hardware, desktop, secrets)
   - `nix-darwin/` — macOS system modules (fonts, homebrew, secrets, system)

   Convention: one concern per file. Single-concern leaf modules are single `.nix` files; directories hold composites (`nixos/desktop/`, `nixos/media/`, …) or a module split across concern files once it outgrows one (`nixos/gaming/`, `common/claude-code/`, `linux/noctalia/`) — each such directory's `default.nix` is a pure `imports` aggregator — or modules with assets (`common/ghostty/`, `linux/niri/`), where `default.nix` is the module itself referencing its sibling asset files.

3. **Hosts** (`hosts/`) — per-machine hardware and overrides

### Secrets Management

Uses **agenix** with age-encrypted `.age` files in `secrets/`. Secret name → file mapping lives in `secrets/definitions.nix` (consumed by both platform secrets modules); recipient keys are declared in `secrets/secrets.nix`. Secrets decrypt to `/run/agenix/` at activation.

### Homebrew (macOS)

Declarative via nix-homebrew + nix-darwin. Taps are immutable (from flake inputs). Casks and App Store apps managed in `modules/nix-darwin/homebrew.nix`.

## Key Conventions

- **Formatter**: alejandra (not nixfmt or nixpkgs-fmt)
- **Theme**: Catppuccin `frappe` flavor, applied globally via the catppuccin flake input
- **Flake structure**: uses `flake-parts` for modular outputs
- **Python**: always use `uv`, never direct `python`/`pip` — enforced in claude-code settings
