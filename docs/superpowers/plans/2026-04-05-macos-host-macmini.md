# macOS host `macmini` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first nix-darwin host `macmini` (Apple Silicon) to the flake with declarative cask-only Homebrew management, mirroring the existing NixOS layout.

**Architecture:** A new shared `profiles/darwin.nix` imports a new `modules/nix-darwin/homebrew` module. A new `hosts/macos/macmini/default.nix` imports that profile, sets the primary user, and wires home-manager reusing `modules/home-manager/common` only. Catppuccin is applied solely via home-manager's `common/theme.nix` (catppuccin's flake does not ship a nix-darwin module). `lib/mk-hosts.nix` registers the host via the existing `mkDarwin` helper.

**Tech Stack:** Nix flakes, flake-parts, nix-darwin, home-manager, catppuccin/nix, Homebrew (managed by nix-darwin).

---

## File Structure

Files created:

- `modules/nix-darwin/homebrew/default.nix` — Homebrew settings module (casks-only policy, strict cleanup)
- `profiles/darwin.nix` — Shared darwin profile (nix settings, fish, unfree, baseline packages, imports homebrew)
- `hosts/macos/macmini/default.nix` — `macmini` host config (hostname, platform, user, catppuccin, HM)

Files modified:

- `lib/mk-hosts.nix` — register `flake.darwinConfigurations.macmini = mkDarwin [...]` and drop the placeholder comment

Reused as-is:

- `modules/home-manager/common/` — portable HM modules, verified no Linux-only imports
- `users/jie.nix` — shared identity

---

## Task 1: Create Homebrew module

**Files:**
- Create: `modules/nix-darwin/homebrew/default.nix`

- [ ] **Step 1: Write the module**

Create `modules/nix-darwin/homebrew/default.nix`:

```nix
# Declarative Homebrew for nix-darwin. Manages casks only.
# NOTE: This does NOT install Homebrew itself. Install it once manually on
# the host before `darwin-rebuild switch`:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false; # don't hit network on every darwin-rebuild
      upgrade = true; # upgrade installed casks on activation
      cleanup = "zap"; # remove anything not declared here
    };
    taps = [];
    brews = [];
    casks = [];
  };
}
```

- [ ] **Step 2: Format with alejandra**

Run: `nix fmt modules/nix-darwin/homebrew/default.nix`
Expected: no changes (or formatting normalized); exit 0.

- [ ] **Step 3: Verify flake still evaluates**

Run: `nix flake check --no-build --show-trace`
Expected: exit 0. The new file is unreferenced so it does not affect evaluation yet.

---

## Task 2: Create darwin profile

**Files:**
- Create: `profiles/darwin.nix`

- [ ] **Step 1: Write the profile**

Create `profiles/darwin.nix`:

```nix
# Darwin profile: shared system settings for macOS hosts.
# Mirrors profiles/workstation.nix in spirit.
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../modules/nix-darwin/homebrew
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # System-level fish: marks it a valid login shell (required when setting
  # users.users.<name>.shell = pkgs.fish).
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

- [ ] **Step 2: Format**

Run: `nix fmt profiles/darwin.nix`
Expected: exit 0.

- [ ] **Step 3: Verify flake evaluates**

Run: `nix flake check --no-build --show-trace`
Expected: exit 0. Still unreferenced from any host.

- [ ] **Step 4: Commit base scaffolding**

```bash
git add modules/nix-darwin/homebrew/default.nix profiles/darwin.nix
git commit -m "darwin: add homebrew module and shared darwin profile"
```

---

## Task 3: (resolved) Catppuccin has no nix-darwin module

**Finding:** `inputs.catppuccin` exposes `homeModules`, `homeManagerModules`, and `nixosModules` only — no darwin module. Verified via:

```bash
nix eval --json --impure --expr \
  'let f = builtins.getFlake (toString ./.); in builtins.attrNames f.inputs.catppuccin'
# → ["_type","devShells","formatter","homeManagerModules","homeModules","inputs",
#    "lastModified",...,"nixosModules","outPath","outputs","packages",...]
```

**Decision:** Do NOT import a catppuccin module in `hosts/macos/macmini/default.nix`,
and do NOT set `catppuccin.enable` / `catppuccin.flavor` at the system level on
darwin. Catppuccin theming will be applied via home-manager's
`modules/home-manager/common/theme.nix`, which is already loaded through the
`common/` import. User-level tools (ghostty, helix, fish, git, etc.) will be
themed automatically.

---

## Task 4: Create `macmini` host file

**Files:**
- Create: `hosts/macos/macmini/default.nix`

- [ ] **Step 1: Write the host file**

Create `hosts/macos/macmini/default.nix`:

```nix
{
  inputs,
  pkgs,
  ...
}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    ../../../profiles/darwin.nix
  ];

  networking.hostName = "macmini";
  networking.computerName = "macmini";

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Location
  time.timeZone = "America/Chicago";

  # Required on modern nix-darwin for user-scoped options (homebrew, HM).
  system.primaryUser = user.me.username;

  users.users.${user.me.username} = {
    home = "/Users/${user.me.username}";
    shell = pkgs.fish;
  };

  # Home-manager reusing common/ only (no darwin-specific HM module yet).
  # Catppuccin is applied via common/theme.nix at the HM level.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      ../../../modules/home-manager/common
    ];
    home.username = user.me.username;
    home.homeDirectory = "/Users/${user.me.username}";
  };

  system.stateVersion = 6;
}
```

- [ ] **Step 2: Format**

Run: `nix fmt hosts/macos/macmini/default.nix`
Expected: exit 0.

- [ ] **Step 3: Verify flake still evaluates (still unreferenced)**

Run: `nix flake check --no-build --show-trace`
Expected: exit 0. This file is still not wired into `mk-hosts.nix`.

---

## Task 5: Register `macmini` in `mk-hosts.nix`

**Files:**
- Modify: `lib/mk-hosts.nix`

- [ ] **Step 1: Add darwinConfigurations block**

Edit `lib/mk-hosts.nix`. Replace the final block:

```nix
  flake.homeConfigurations = {
    "jie@server" = mkHome "x86_64-linux" [(../hosts/foreign + "/jie@server")];
  };

  # flake.darwinConfigurations.<macname> = mkDarwin [ ../hosts/darwin/<macname> ];
}
```

with:

```nix
  flake.homeConfigurations = {
    "jie@server" = mkHome "x86_64-linux" [(../hosts/foreign + "/jie@server")];
  };

  flake.darwinConfigurations = {
    macmini = mkDarwin [../hosts/macos/macmini];
  };
}
```

- [ ] **Step 2: Format**

Run: `nix fmt lib/mk-hosts.nix`
Expected: exit 0.

- [ ] **Step 3: Evaluate the darwin config**

Run: `nix eval --show-trace '.#darwinConfigurations.macmini.system.outPath' 2>&1 | tail -30`
Expected: a store path `/nix/store/...-darwin-system-...` with no evaluation errors.

If evaluation fails, read the trace and fix. Common causes:
- Wrong catppuccin attribute path → fix Task 4 output.
- Missing `system.primaryUser` for user-scoped options → already set in Task 4.
- Option naming drift in nix-darwin (e.g. `system.stateVersion` value type) → consult the error and adjust.

- [ ] **Step 4: Build the darwin system (optional, cross-platform)**

Run: `nix build --show-trace '.#darwinConfigurations.macmini.system'`
Expected: build succeeds; `./result` symlink created.

Note: This can be run from Linux or macOS. On Linux it will build what it can cross-build; any darwin-only builtins may force a native build. If it fails on Linux with a platform mismatch, skip this step — evaluation success from Step 3 is sufficient until the actual macmini host runs `darwin-rebuild switch`.

- [ ] **Step 5: Final flake check**

Run: `nix flake check --show-trace`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add lib/mk-hosts.nix hosts/macos/macmini/default.nix
git commit -m "darwin: add macmini host and wire into flake"
```

---

## Verification Summary

After all tasks complete:

- [ ] `nix flake check --show-trace` exits 0.
- [ ] `nix eval '.#darwinConfigurations.macmini.system.outPath'` returns a store path.
- [ ] `git log --oneline -3` shows two new commits: "darwin: add homebrew module and shared darwin profile" and "darwin: add macmini host and wire into flake".
- [ ] Repo is clean (`git status` shows no untracked/modified files).

Deferred to the macmini host at activation time (not part of this plan):

- Manual Homebrew install.
- `sudo darwin-rebuild switch --flake .#macmini`.
