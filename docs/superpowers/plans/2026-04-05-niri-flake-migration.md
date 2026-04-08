# niri-flake Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate niri configuration from a hand-written `config.kdl` symlinked via `xdg.configFile` into niri-flake's typed home-manager module, so settings are type-checked Nix code.

**Architecture:** Add `niri-flake` as a new flake input. Import only its home-manager module (`homeModules.config`) locally inside `modules/home-manager/linux/niri.nix`, where the existing niri configuration lives. Replace the `xdg.configFile."niri/config.kdl".source = …` line with `programs.niri.settings = { … }`. The nixpkgs-side `programs.niri.enable = true;` in `modules/nixos/desktop/niri.nix` is left untouched — niri-flake is HM-only in this repo. After verification, the orphaned `modules/home-manager/linux/niri/config.kdl` and its directory are removed.

**Tech Stack:** Nix flakes (`flake-parts`), home-manager (NixOS-embedded via `lib/mk-hosts.nix`), niri window manager, niri-flake (`github:sodiboo/niri-flake`).

**Target host:** `naptop` (the only Linux HM consumer in this repo).

**Validation strategy:** This is a configuration migration, not application code — there are no unit tests to write. Each task ends with a concrete verification command (`nix flake check`, `nixos-rebuild dry-build`, `diff` of generated vs. current `config.kdl`), and the final task is a live smoke-test on the running system.

**Working tree state:** At the start of this plan, `modules/home-manager/linux/niri/config.kdl` has unstaged modifications (the `accel-speed`/`scroll-factor` touchpad-tuning edits from the prior conversation turn). These values are captured in the plan below and end up in the new `programs.niri.settings`. The file itself is ultimately deleted in Task 6 — the unstaged edits do not need to be committed separately.

**Rollback:** Every task ends in a git commit. Any task's commit can be reverted with `git revert <sha>`; NixOS generation rollback (`sudo nixos-rebuild switch --rollback`) is always available as a runtime safety net.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `flake.nix` | Add `niri-flake` input with `inputs.nixpkgs.follows = "nixpkgs"`. | Task 1 |
| `modules/home-manager/linux/niri.nix` | Import niri-flake HM module; declare `programs.niri.settings`; keep existing `home.packages` list. | Tasks 2–3 |
| `hosts/nixos/naptop/default.nix` | Add `inputs` to `home-manager.extraSpecialArgs` so HM modules can reference flake inputs. | Task 2 |
| `modules/home-manager/linux/niri/config.kdl` | **Delete** — generated config replaces it. | Task 6 |
| `modules/home-manager/linux/niri/` (directory) | **Delete** after the file is removed (empty directory). | Task 6 |
| `modules/nixos/desktop/niri.nix` | **Unchanged.** Continues to provide `programs.niri.enable = true;` from nixpkgs. | — |
| `lib/mk-hosts.nix` | **Unchanged.** niri-flake module is imported locally, not via `hmSharedModules`. | — |

Each task produces a single working, reviewable commit.

---

## Niri-flake API reference (for use in the tasks below)

These patterns are used verbatim throughout the plan — do not guess, match these shapes:

**Import:**
```nix
imports = [inputs.niri-flake.homeModules.config];
```

**Output mode:**
```nix
outputs."eDP-1" = {
  mode = { width = 1920; height = 1200; refresh = 120.043; };
  scale = 1.25;
};
```

**Binds — spawn action:**
```nix
"Mod+D" = {
  action.spawn = "fuzzel";
  hotkey-overlay.title = "App launcher: fuzzel";
};

"XF86AudioRaiseVolume" = {
  action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"];
  allow-when-locked = true;
};
```

**Binds — no-argument actions** use the tagged-union attrset form `action.<name> = {}`:
```nix
"Mod+Q".action.close-window = {};
"Mod+F".action.maximize-column = {};
```

**Binds — actions with an argument:**
```nix
"Mod+1".action.focus-workspace = 1;
"Mod+Shift+1".action.move-column-to-workspace = 1;
```

---

### Task 1: Add niri-flake as a flake input

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add the input**

Edit `flake.nix`. After the `zen-browser` input block and before `catppuccin`, add:

```nix
    niri-flake.url = "github:sodiboo/niri-flake";
    niri-flake.inputs.nixpkgs.follows = "nixpkgs";
```

The full `inputs = { … }` block should now read:

```nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    niri-flake.url = "github:sodiboo/niri-flake";
    niri-flake.inputs.nixpkgs.follows = "nixpkgs";

    catppuccin.url = "github:catppuccin/nix";
  };
```

- [ ] **Step 2: Lock the new input**

Run from the repo root:

```bash
cd /home/jie/repo/nice
nix flake lock
```

Expected: command completes silently (or prints that `flake.lock` was updated). A new `niri-flake` entry appears in `flake.lock`.

- [ ] **Step 3: Verify the flake still evaluates**

```bash
nix flake check --no-build
```

Expected: exits 0. (`--no-build` skips building derivations so this runs fast and only checks evaluation.)

If errors appear, read them carefully — a legitimate failure here means a typo in the input URL or a syntax error.

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock
git commit -m "flake: add niri-flake input (HM-only)"
```

---

### Task 2: Rewrite niri.nix — module import + non-binds settings

**Files:**
- Modify: `modules/home-manager/linux/niri.nix` (full rewrite)

This task replaces the `xdg.configFile` symlink with the niri-flake module and translates every setting *except* `binds`. `binds` gets its own task. The orphaned `niri/config.kdl` file is left on disk for a later diff comparison and deleted in Task 6.

- [ ] **Step 1: Rewrite `modules/home-manager/linux/niri.nix`**

Replace the entire file contents with:

```nix
{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.niri-flake.homeModules.config];

  programs.niri.settings = {
    input = {
      keyboard.xkb.layout = "us";
      touchpad = {
        tap = true;
        natural-scroll = true;
        # macOS-ish feel: adaptive accel, slower base speed. Range -1.0 .. 1.0.
        accel-profile = "adaptive";
        accel-speed = -0.3;
        scroll-factor = 0.5;
      };
      mouse = {
        accel-profile = "adaptive";
        accel-speed = -0.3;
        scroll-factor = 0.5;
      };
    };

    outputs."eDP-1" = {
      # LG 14" 1920x1200 @ 120Hz, ~189 DPI
      mode = {
        width = 1920;
        height = 1200;
        refresh = 120.043;
      };
      scale = 1.25;
      # variable-refresh-rate = true;  # causes cursor micro-stutter on this panel
    };

    layout = {
      gaps = 8;
      center-focused-column = "never";
      preset-column-widths = [
        {proportion = 0.33333;}
        {proportion = 0.5;}
        {proportion = 0.66667;}
      ];
      default-column-width = {proportion = 0.5;};
      focus-ring.width = 2;
    };

    prefer-no-csd = true;
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    # binds added in Task 3
    binds = {};
  };

  # niri tools & niri's ecosystem companions.
  home.packages = with pkgs; [
    fuzzel # app launcher (Mod+D)
    brightnessctl # brightness keys
    wl-clipboard # wayland clipboard
    grim # screenshot backend (used by niri's built-in screenshot)
    slurp # region selection
  ];
}
```

Key differences from the old file:
- `xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;` is removed (this is what made the old `config.kdl` file the source of truth).
- The function signature gains `inputs`. NOTE: `inputs` is threaded into **NixOS-level** `specialArgs` at `lib/mk-hosts.nix:9`, but **not** into home-manager's `extraSpecialArgs` — HM modules run in a separate module context. This task also adds `inputs` to `home-manager.extraSpecialArgs` in the naptop host file (see Step 1b).
- `home.packages` is preserved verbatim.

- [ ] **Step 1b: Thread `inputs` into home-manager for naptop**

Edit `hosts/nixos/naptop/default.nix`. Two changes:

1. Add `inputs` to the top-level function signature:

   ```nix
   {pkgs, ...}: …  →  {inputs, pkgs, ...}: …
   ```

2. Add `inputs` to `home-manager.extraSpecialArgs` (currently on line 39):

   ```nix
   home-manager.extraSpecialArgs = {inherit user;};  →  home-manager.extraSpecialArgs = {inherit inputs user;};
   ```

Without both changes, `imports = [inputs.niri-flake.homeModules.config]` triggers infinite recursion because `inputs` isn't in scope.

- [ ] **Step 2: Verify the flake evaluates with the empty binds**

```bash
cd /home/jie/repo/nice
nix flake check --no-build
```

Expected: exits 0. If the output contains errors about unknown options under `programs.niri.settings`, those are niri-flake schema mismatches — read them and correct the offending attr name (e.g. `centre-focused-column` vs `center-focused-column`).

- [ ] **Step 3: Verify the naptop NixOS config evaluates**

```bash
cd /home/jie/repo/nice
nix eval .#nixosConfigurations.naptop.config.system.build.toplevel.drvPath --raw
```

Expected: prints a `/nix/store/…-nixos-system-naptop-…drv` path and exits 0. This proves the full system — including HM — evaluates cleanly.

- [ ] **Step 4: Commit**

```bash
git add modules/home-manager/linux/niri.nix hosts/nixos/naptop/default.nix
git commit -m "niri: adopt niri-flake HM module for settings (no binds yet)"
```

---

### Task 3: Translate binds

**Files:**
- Modify: `modules/home-manager/linux/niri.nix` — replace `binds = {};` with the full binds attrset.

The KDL config has 30 binds. Several pairs do the same thing (arrow + vim keys for focus); per the design decision, those share `let`-bound values.

- [ ] **Step 1: Replace the `binds = {};` line**

In `modules/home-manager/linux/niri.nix`, find the line `binds = {};` (near the end of the `programs.niri.settings` attrset) and replace it with:

```nix
    binds = let
      focusColLeft  = { action.focus-column-left  = {}; };
      focusColRight = { action.focus-column-right = {}; };
      focusWinUp    = { action.focus-window-up    = {}; };
      focusWinDown  = { action.focus-window-down  = {}; };
    in {
      # Apps
      "Mod+T" = {
        action.spawn = "ghostty";
        hotkey-overlay.title = "Terminal: ghostty";
      };
      "Mod+D" = {
        action.spawn = "fuzzel";
        hotkey-overlay.title = "App launcher: fuzzel";
      };
      "Mod+B" = {
        action.spawn = "zen";
        hotkey-overlay.title = "Browser: zen";
      };

      # Session
      "Mod+Q".action.close-window = {};
      "Mod+Shift+E".action.quit = {};
      "Mod+Shift+P".action.power-off-monitors = {};
      "Mod+Shift+L".action.spawn = ["loginctl" "lock-session"];

      # Focus (arrow + vim keys share actions)
      "Mod+Left"  = focusColLeft;
      "Mod+H"     = focusColLeft;
      "Mod+Right" = focusColRight;
      "Mod+L"     = focusColRight;
      "Mod+Up"    = focusWinUp;
      "Mod+K"     = focusWinUp;
      "Mod+Down"  = focusWinDown;
      "Mod+J"     = focusWinDown;

      # Move
      "Mod+Shift+Left".action.move-column-left  = {};
      "Mod+Shift+Right".action.move-column-right = {};
      "Mod+Shift+Up".action.move-window-up      = {};
      "Mod+Shift+Down".action.move-window-down  = {};

      # Workspaces
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+Shift+1".action.move-column-to-workspace = 1;
      "Mod+Shift+2".action.move-column-to-workspace = 2;
      "Mod+Shift+3".action.move-column-to-workspace = 3;
      "Mod+Shift+4".action.move-column-to-workspace = 4;

      # Column widths
      "Mod+R".action.switch-preset-column-width = {};
      "Mod+F".action.maximize-column    = {};
      "Mod+Shift+F".action.fullscreen-window = {};

      # Screenshot
      "Print".action.screenshot            = {};
      "Mod+Print".action.screenshot-window = {};

      # Volume / brightness (laptop keys)
      "XF86AudioRaiseVolume" = {
        action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"];
        allow-when-locked = true;
      };
      "XF86AudioLowerVolume" = {
        action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"];
        allow-when-locked = true;
      };
      "XF86AudioMute" = {
        action.spawn = ["wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"];
        allow-when-locked = true;
      };
      "XF86MonBrightnessUp".action.spawn   = ["brightnessctl" "set" "10%+"];
      "XF86MonBrightnessDown".action.spawn = ["brightnessctl" "set" "10%-"];
    };
```

- [ ] **Step 2: Verify evaluation**

```bash
cd /home/jie/repo/nice
nix flake check --no-build
```

Expected: exits 0.

If niri-flake's schema rejects any action name (for example, if an action is named differently from the KDL keyword), the error message will point at the exact offending line. Correct the action name and re-run.

- [ ] **Step 3: Format with alejandra**

The repo's formatter is alejandra (declared at `flake.nix:28`). Run it on the touched file:

```bash
cd /home/jie/repo/nice
nix fmt modules/home-manager/linux/niri.nix
```

Expected: exits 0. Re-read the file afterward to confirm formatting looks sane.

- [ ] **Step 4: Re-verify evaluation after formatting**

```bash
nix flake check --no-build
```

Expected: exits 0.

- [ ] **Step 5: Commit**

```bash
git add modules/home-manager/linux/niri.nix
git commit -m "niri: translate all binds into programs.niri.settings"
```

---

### Task 4: Dry-build naptop and diff generated config.kdl against the current one

**Files:** (none modified)

This task proves that niri-flake will generate a `config.kdl` that is semantically equivalent to the current one, *before* switching to it.

- [ ] **Step 1: Dry-build the naptop system**

```bash
cd /home/jie/repo/nice
sudo nixos-rebuild dry-build --flake .#naptop
```

Expected: builds all derivations in the dependency graph without activating anything. Exits 0. The output ends with a line like `would install …` (no errors).

- [ ] **Step 2: Locate the generated config.kdl in the build result**

niri-flake places the generated file at `$XDG_CONFIG_HOME/niri/config.kdl` in the home-manager activation. Instead of activating, inspect it via the HM derivation:

```bash
cd /home/jie/repo/nice
nix build --no-link --print-out-paths \
  .#nixosConfigurations.naptop.config.home-manager.users.jie.home.activationPackage
```

Expected: prints a `/nix/store/…-home-manager-generation` path. Call that path `$HM_GEN`.

Then find the generated niri config:

```bash
HM_GEN=$(nix build --no-link --print-out-paths .#nixosConfigurations.naptop.config.home-manager.users.jie.home.activationPackage)
find "$HM_GEN" -path '*niri/config.kdl' -print
```

Expected: prints one path under `$HM_GEN/home-files/.config/niri/config.kdl` (or similar). Call that `$GENERATED`.

- [ ] **Step 3: Diff generated vs current**

```bash
GENERATED=$(find "$HM_GEN" -path '*niri/config.kdl' | head -n1)
diff -u modules/home-manager/linux/niri/config.kdl "$GENERATED" || true
```

Expected: the diff is non-empty (formatting, ordering, and comment differences are expected) but every *semantic* line from the old file is present in the new one:
- Every binding from the old `binds` block (30 total).
- `input { touchpad { tap; natural-scroll; accel-profile "adaptive"; accel-speed -0.3; scroll-factor 0.5 } }` and equivalent `mouse { … }`.
- `output "eDP-1"` with mode and scale.
- `layout` with gaps=8, three preset column widths, default-column-width proportion=0.5, focus-ring width=2.
- `prefer-no-csd`, `screenshot-path`.

If a semantic line is missing, go back to Task 2 or Task 3 and find the missing attr.

- [ ] **Step 4: (No commit — this task only validates)**

No files changed in this task. Proceed to Task 5.

---

### Task 5: Activate the new system

**Files:** (none modified)

- [ ] **Step 1: Switch to the new generation**

```bash
cd /home/jie/repo/nice
sudo nixos-rebuild switch --flake .#naptop
```

Expected: builds and activates. Home-manager reports it installed the new `niri/config.kdl`. Niri auto-reloads config on change — the reload should happen within a second or two.

If activation fails because HM detects a collision with `~/.config/niri/config.kdl` already existing as a regular file, remove it manually (`rm ~/.config/niri/config.kdl`) and re-run the switch. This can happen if an earlier generation wrote it as a file rather than a symlink.

- [ ] **Step 2: Smoke-test keybinds (live)**

Run each check. A failure means the corresponding bind in Task 3 is wrong.

| Bind | Action | Expected |
|---|---|---|
| `Mod+D` | fuzzel launches | Fuzzel app launcher appears |
| `Mod+T` | ghostty launches | Terminal opens |
| `Mod+Q` (in a window) | closes focused window | Window closes |
| `Mod+Left` / `Mod+H` | focus column left | Focus moves |
| `Mod+1` | focus workspace 1 | Workspace switches |
| `XF86MonBrightnessUp` | brightness up | Screen brighter |
| `Print` | screenshot | Screenshot saved under `~/Pictures/Screenshots/` |

- [ ] **Step 3: Smoke-test touchpad feel**

Move the cursor and scroll in a browser. Expected: the same `-0.3` accel-speed and `0.5` scroll-factor feel as before the migration (nothing changes — these values are a verbatim port from today's config).

- [ ] **Step 4: Verify `~/.config/niri/config.kdl` is now a store symlink**

```bash
readlink ~/.config/niri/config.kdl
```

Expected: a `/nix/store/…` path. This confirms HM is now managing the file.

- [ ] **Step 5: (No commit — this task only activates & validates)**

---

### Task 6: Delete the orphaned config.kdl and its directory

**Files:**
- Delete: `modules/home-manager/linux/niri/config.kdl`
- Delete: `modules/home-manager/linux/niri/` (now empty)

- [ ] **Step 1: Confirm the file is no longer referenced**

```bash
cd /home/jie/repo/nice
grep -r "niri/config.kdl" --include='*.nix' .
```

Expected: no matches. If there are matches, they are dangling references that must be fixed before deletion.

- [ ] **Step 2: Delete the file and directory**

```bash
git rm modules/home-manager/linux/niri/config.kdl
rmdir modules/home-manager/linux/niri
```

The `rmdir` fails with `Directory not empty` if anything else is in there — in that case, stop and investigate (`ls modules/home-manager/linux/niri`).

- [ ] **Step 3: Verify the system still evaluates**

```bash
nix flake check --no-build
```

Expected: exits 0.

- [ ] **Step 4: Commit**

```bash
git add -A modules/home-manager/linux/
git commit -m "niri: remove orphaned config.kdl (now generated from Nix)"
```

- [ ] **Step 5: Rebuild one more time to confirm**

```bash
sudo nixos-rebuild switch --flake .#naptop
```

Expected: "no changes" or a trivial generation bump (nothing user-visible should change — the generated config.kdl is already in place). Live niri session stays working.

---

## Done criteria

- `flake.nix` has a `niri-flake` input, `flake.lock` is updated.
- `modules/home-manager/linux/niri.nix` uses `programs.niri.settings`; no `xdg.configFile` line for niri remains.
- `modules/home-manager/linux/niri/` directory is gone.
- `~/.config/niri/config.kdl` is a `/nix/store` symlink.
- Every keybind from the original `config.kdl` works.
- Touchpad accel-speed `-0.3` and scroll-factor `0.5` feel identical to pre-migration.
- `nix flake check --no-build` exits 0.
- Six commits exist (Tasks 1, 2, 3, 6 each produce a commit; Tasks 4 and 5 are verification-only).
