# macOS host `macmini` — design

## Purpose

Add a first nix-darwin host (`macmini`, Apple Silicon) to the flake, with
declarative Homebrew cask management. Mirrors the existing NixOS host layout
so a second Mac can be added later without restructuring.

## Scope

In scope:

- New darwin host `macmini` at `hosts/macos/macmini/`.
- New shared darwin profile at `profiles/darwin.nix`.
- New Homebrew module at `modules/nix-darwin/homebrew/` managing **casks only**.
- Wire `darwinConfigurations.macmini` into `lib/mk-hosts.nix`.
- Home-manager integrated into the darwin system config, reusing
  `modules/home-manager/common` only.

Out of scope:

- Any actual cask list (empty for now, user will add as needed).
- A `modules/home-manager/darwin/` module (the dir exists but stays empty).
- Installing Homebrew itself — must be done once manually before first
  `darwin-rebuild switch`.
- Taps, brews (formulae), and Mac App Store (`masApps`) — casks only.

## File layout

```
profiles/
  darwin.nix                          # NEW
modules/nix-darwin/
  homebrew/
    default.nix                       # NEW
hosts/macos/
  macmini/
    default.nix                       # NEW
lib/mk-hosts.nix                      # EDIT
```

## Components

### `profiles/darwin.nix`

Shared profile for any future darwin host. Mirrors `profiles/workstation.nix`.

Responsibilities:

- `imports = [ ../modules/nix-darwin/homebrew ]`.
- `nixpkgs.config.allowUnfree = true`.
- `nix.settings.experimental-features = ["nix-command" "flakes"]`.
- `programs.fish.enable = true` (system fish; matches workstation profile).
- `environment.systemPackages` — baseline: `git`, agenix CLI from
  `inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default`.
- Does NOT set `catppuccin.enable`; that is host-level (see `hosts/macos/macmini`).

### `modules/nix-darwin/homebrew/default.nix`

Declarative Homebrew management. Cask-only policy.

```nix
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };
    taps = [];
    brews = [];
    casks = [];
  };
}
```

- `cleanup = "zap"` — strict: any cask not declared here is removed on
  activation. User explicitly chose this.
- `homebrew.enable = true` only manages state; Homebrew itself must be
  installed manually once:
  `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`.

### `hosts/macos/macmini/default.nix`

Host-specific config. Shape:

```nix
{inputs, pkgs, ...}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    ../../../profiles/darwin.nix
    inputs.catppuccin.nixDarwinModules.catppuccin
  ];

  networking.hostName = "macmini";
  networking.computerName = "macmini";

  nixpkgs.hostPlatform = "aarch64-darwin";
  time.timeZone = "America/Chicago";

  catppuccin.enable = true;
  catppuccin.flavor = user.theme.flavor;

  system.primaryUser = user.me.username;
  users.users.${user.me.username} = {
    home = "/Users/${user.me.username}";
    shell = pkgs.fish;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [ ../../../modules/home-manager/common ];
    home.username = user.me.username;
    home.homeDirectory = "/Users/${user.me.username}";
  };

  system.stateVersion = 6;
}
```

Notes:

- `inputs.catppuccin.nixDarwinModules.catppuccin` attribute name to be
  verified against the flake at build time; if the attribute differs
  (e.g. `darwinModules`), adjust accordingly during implementation.
- `system.stateVersion` on nix-darwin is an integer (currently `6`),
  not a NixOS-style release string.
- `system.primaryUser` is required on modern nix-darwin when any
  user-scoped options (like `homebrew` activation or home-manager) need
  a primary user.

### `lib/mk-hosts.nix`

Add a darwin block:

```nix
flake.darwinConfigurations = {
  macmini = mkDarwin [../hosts/macos/macmini];
};
```

Remove the now-obsolete comment hint at the bottom of the file.

## Verification

After implementation:

- `nix flake check` succeeds.
- `nix build .#darwinConfigurations.macmini.system` succeeds (can be
  built cross-platform on a Linux box; won't activate).
- On the actual `macmini` host, after manually installing Homebrew:
  `sudo darwin-rebuild switch --flake .#macmini` succeeds.

## Open questions / risks

- Catppuccin nix-darwin module attribute path — verify at implementation
  time.
- `modules/home-manager/common` has been reviewed and contains no
  Linux-only imports; safe to reuse on darwin.
