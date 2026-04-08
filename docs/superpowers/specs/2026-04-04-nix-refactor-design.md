# Nix Config Refactor — Design

**Date:** 2026-04-04
**Status:** Approved (pending user spec review)

## Goal

Refactor the current flat single-host Nix flake (laptop `naptop`, user `jie`) into
a multi-host, multi-OS structure that will hold, from day one:

| Host        | Platform       | Nix mode                              |
|-------------|----------------|---------------------------------------|
| naptop      | NixOS          | full system                           |
| `<mac>`     | macOS          | nix-darwin full system                |
| server      | Ubuntu         | standalone home-manager (user env)    |
| nas         | NixOS          | full system                           |

All four are real and near-term. The refactor migrates the existing laptop
config without behavior change, and leaves the other three hosts as
ready-to-fill skeletons.

## Non-goals

- No secrets management (agenix) — deferred until first real secret is needed.
- No custom packages / overlays — current flake has none.
- No devshell, formatter, or git hooks.
- No `nixos-unified` framework — we use `flake-parts` directly.
- No auto-discovery of hosts — explicit enumeration while host count ≤ ~8.

## Architectural decisions

1. **Framework: `flake-parts` + small helpers.** No `nixos-unified`. Keeps the
   flake readable and explicit; easy to reason about.
2. **Module organization: OS folders + profiles (hybrid).** `modules/{nixos,
   darwin,home}/` hold OS-specific building blocks; `profiles/` hold role
   compositions (`workstation`, `server`, `nas`). Hosts are thin and import a
   profile plus their hardware.
3. **Host layout: one folder per host.** Each host owns its `default.nix` and
   `hardware.nix` (and anything host-specific).
4. **Foreign distros go under `hosts/foreign/`.** Established Nix community
   term for "standalone home-manager on a non-NixOS system".
5. **Explicit host wiring.** `lib/mk-hosts.nix` is a flake-parts module that
   declares each host by name. Swap to `readDir` iteration only if host count
   grows past ~8.
6. **Identity centralized.** `users/jie.nix` holds username, fullname, email,
   ssh key, and theme preference (`catppuccin.flavor`). Consumed by both NixOS
   and home-manager sides to avoid drift.

## Directory layout

```
/home/jie/repo/nice/
├── flake.nix                     # inputs + flake-parts wiring
├── flake.lock
├── lib/
│   └── mk-hosts.nix              # mkNixos, mkDarwin, mkHome helpers
├── hosts/
│   ├── nixos/
│   │   ├── naptop/
│   │   │   ├── default.nix       # host entry
│   │   │   └── hardware.nix      # hardware-configuration.nix
│   │   └── nas/                  # skeleton
│   │       └── default.nix
│   ├── darwin/
│   │   └── <macname>/            # skeleton
│   │       └── default.nix
│   └── foreign/
│       └── jie@server/           # skeleton (standalone home-manager)
│           └── default.nix
├── profiles/
│   ├── workstation.nix
│   ├── server.nix
│   └── nas.nix
├── modules/
│   ├── nixos/
│   │   ├── boot/                 # systemd-boot, plymouth, kernel quirks
│   │   ├── hardware/             # power, audio, kanata
│   │   └── desktop/              # gnome, input-method (fcitx5+rime), fonts
│   ├── darwin/                   # (empty scaffold)
│   └── home/
│       ├── common/               # cross-OS: shell, git, editor, catppuccin
│       ├── linux/                # linux-only HM: e.g., wechat-uos
│       └── darwin/               # darwin-only HM
├── overlays/                     # (empty scaffold, may be omitted)
└── users/
    └── jie.nix                   # identity + theme attrs
```

## flake.nix wiring (sketch)

```nix
{
  inputs = {
    nixpkgs.url       = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url   = "github:hercules-ci/flake-parts";
    home-manager.url  = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url    = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    zen-browser.url   = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url    = "github:catppuccin/nix";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports = [ ./lib/mk-hosts.nix ];
    };
}
```

`lib/mk-hosts.nix` provides:

- `mkNixos hostname modules` → `nixosSystem` with `home-manager.nixosModules.home-manager` preloaded, `specialArgs = { inherit inputs; }`.
- `mkDarwin hostname modules` → `nix-darwin.lib.darwinSystem` similarly.
- `mkHome system modules` → `home-manager.lib.homeManagerConfiguration` with
  `extraSpecialArgs = { inherit inputs; }` and `config.allowUnfree = true`.

It then declares:

```nix
flake.nixosConfigurations.naptop = mkNixos "naptop" [ ../hosts/nixos/naptop ];
flake.nixosConfigurations.nas    = mkNixos "nas"    [ ../hosts/nixos/nas ];
# flake.darwinConfigurations.<mac>    = mkDarwin ...
flake.homeConfigurations."jie@server" =
  mkHome "x86_64-linux" [ ../hosts/foreign/jie@server ];
```

## Migration of current config

The existing `configuration.nix` and `home.nix` decompose as follows. **No
behavior changes** — this refactor is pure reorganization.

### `hosts/nixos/naptop/default.nix` imports
- `./hardware.nix` (verbatim from current `hardware-configuration.nix`)
- `modules/nixos/boot/` — systemd-boot, plymouth, `linuxPackages_latest`,
  `extraModprobeConfig` (Panther Lake CS42L45 workaround)
- `modules/nixos/hardware/power.nix` — thermald, auto-cpufreq,
  powerManagement, logind lid-switch=lock
- `modules/nixos/hardware/audio.nix` — pipewire, enableAllFirmware, fwupd
- `modules/nixos/hardware/kanata.nix` — caps→esc/ctrl
- `modules/nixos/desktop/gnome.nix` — gdm, gnome, gsettings overrides, fonts,
  cursor
- `modules/nixos/desktop/input-method.nix` — fcitx5 + rime
- `profiles/workstation.nix` — allowUnfree, nix experimental-features, niri,
  system packages (helix, wifitui, git, zen-browser, banana-cursor)
- `users/jie.nix`
- home-manager block wiring `users.jie → modules/home/common + modules/home/linux`

### Host-local (stays in `hosts/nixos/naptop/default.nix`)
- `networking.hostName = "naptop"`
- `swapDevices` (8 GB swapfile)
- `system.stateVersion = "26.05"`

### home-manager migration
- `modules/home/common/` — catppuccin enable, home-manager self-management,
  `stateVersion`, `ghostty`, `claude-code`, `zed-editor`
- `modules/home/linux/packages.nix` — `wechat-uos`

### Theme centralization
`users/jie.nix` exports `theme.flavor = "frappe"`. Both the NixOS catppuccin
module and the HM catppuccin module read from this attr, so flavor changes in
one place.

## Testing / verification

After migration:

1. `nix flake check` — flake evaluates.
2. `sudo nixos-rebuild build --flake .#naptop` — build succeeds.
3. `nix build .#nixosConfigurations.naptop.config.system.build.toplevel` —
   equivalent.
4. Diff the produced toplevel closure against the pre-refactor build; paths
   should match modulo unavoidable metadata (e.g., derivation hashes stay
   identical for unchanged modules).
5. `sudo nixos-rebuild switch --flake .#naptop` — activate and use the system
   normally for one session to confirm nothing regressed (GNOME, fcitx5,
   kanata, audio, lid behavior).

Skeleton hosts (`nas`, darwin, `jie@server`) must at minimum evaluate without
errors under `nix flake check`, even if their modules are near-empty.

## Open items (deferred, not blockers)

- macOS hostname — fill when that machine exists.
- Secrets (agenix) — separate future task.
- Custom packages / overlays — add when needed.
- Devshell + formatter + git hooks — add when needed.
