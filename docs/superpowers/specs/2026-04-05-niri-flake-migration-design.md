# niri-flake migration — design

**Date:** 2026-04-05
**Status:** Approved for implementation planning
**Scope:** Replace the raw `config.kdl` symlink for niri with niri-flake's typed
home-manager module (`programs.niri.settings`), on host `naptop`.

## Goal

Configure niri declaratively through Nix instead of maintaining a hand-written
`config.kdl` file. Adopt niri-flake
(<https://github.com/sodiboo/niri-flake>) for its home-manager module only.
System-level niri stays on the nixpkgs module.

## Non-goals

- Switching the NixOS-side `programs.niri` from nixpkgs to niri-flake's module.
- Adding keybinds or behavior beyond what today's `config.kdl` already has.
- Theming or styling changes beyond the settings that already exist.
- Changes to any host other than `naptop`.

## Architecture

### Flake wiring

Add one input to `flake.nix`:

```nix
niri-flake.url = "github:sodiboo/niri-flake";
niri-flake.inputs.nixpkgs.follows = "nixpkgs";
```

No changes to `lib/mk-hosts.nix`. The niri-flake home-manager module is **not**
added to `hmSharedModules`: niri is Linux-only and currently only `naptop` has a
Linux HM user, so putting it in shared modules would pollute the Darwin and
foreign-server HM configs for no gain. The module is imported locally at the
only place it is used.

### Module import site

`modules/home-manager/linux/niri.nix` imports `inputs.niri-flake.homeModules.niri`
and populates `programs.niri.settings`. The file's signature gains `inputs`
(already threaded via `extraSpecialArgs` / `specialArgs`).

### System-level niri

`modules/nixos/desktop/niri.nix` is unchanged — it keeps
`programs.niri.enable = true;` from nixpkgs (provides the session and polkit
wiring). The niri binary continues to come from nixpkgs-unstable.

## File-level changes

| File | Change |
|---|---|
| `flake.nix` | Add `niri-flake` input (2 lines). |
| `modules/home-manager/linux/niri.nix` | Rewrite: import niri-flake HM module, replace `xdg.configFile."niri/config.kdl".source` with `programs.niri.settings = { … }`. Keep existing `home.packages` list (fuzzel, brightnessctl, wl-clipboard, grim, slurp). |
| `modules/home-manager/linux/niri/config.kdl` | Delete (superseded by generated config). |
| `modules/home-manager/linux/niri/` | Delete if empty after file removal. |

### Shape of the new `niri.nix`

```nix
{inputs, pkgs, ...}: {
  imports = [inputs.niri-flake.homeModules.niri];

  programs.niri.settings = {
    input = { … };
    outputs."eDP-1" = { … };
    layout = { … };
    binds = { … };
    prefer-no-csd = true;
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
  };

  home.packages = with pkgs; [
    fuzzel brightnessctl wl-clipboard grim slurp
  ];
}
```

## Settings translation

The translation is a faithful 1:1 port of today's `config.kdl` with light Nix
cleanup (arrow/vim key pairs deduped via `let` bindings). No behavior change.

### Direct mappings

| KDL today | Nix attr |
|---|---|
| `input { keyboard { xkb { layout "us" } } }` | `input.keyboard.xkb.layout = "us";` |
| `input { touchpad { tap; natural-scroll; accel-profile "adaptive"; accel-speed -0.3; scroll-factor 0.5 } }` | `input.touchpad = { tap = true; natural-scroll = true; accel-profile = "adaptive"; accel-speed = -0.3; scroll-factor = 0.5; };` |
| `input { mouse { accel-profile "adaptive"; accel-speed -0.3; scroll-factor 0.5 } }` | `input.mouse = { accel-profile = "adaptive"; accel-speed = -0.3; scroll-factor = 0.5; };` |
| `output "eDP-1" { mode "1920x1200@120.043"; scale 1.25 }` | `outputs."eDP-1" = { mode = { width = 1920; height = 1200; refresh = 120.043; }; scale = 1.25; };` |
| `layout { gaps 8; center-focused-column "never"; preset-column-widths { … }; default-column-width { proportion 0.5 }; focus-ring { width 2 } }` | `layout = { gaps = 8; center-focused-column = "never"; preset-column-widths = [ … ]; default-column-width = { proportion = 0.5; }; focus-ring.width = 2; };` |
| `prefer-no-csd` | `prefer-no-csd = true;` |
| `screenshot-path "..."` | `screenshot-path = "…";` |

### Binds

niri-flake expects `binds` as an attrset keyed by chord-string, value an action
attrset. Arrow/vim key pairs are deduped:

```nix
binds = let
  focusColLeft  = { focus-column-left  = {}; };
  focusColRight = { focus-column-right = {}; };
  focusWinUp    = { focus-window-up    = {}; };
  focusWinDown  = { focus-window-down  = {}; };
in {
  "Mod+Left"  = focusColLeft;  "Mod+H" = focusColLeft;
  "Mod+Right" = focusColRight; "Mod+L" = focusColRight;
  "Mod+Up"    = focusWinUp;    "Mod+K" = focusWinUp;
  "Mod+Down"  = focusWinDown;  "Mod+J" = focusWinDown;
  # app launchers, session, move, workspaces, widths,
  # screenshot, volume/brightness — per today's config.kdl.
};
```

All existing bindings are preserved: app launchers (Mod+T/D/B), session
(Mod+Q, Mod+Shift+E/P/L), column moves (Mod+Shift+Arrow), workspaces 1–4 and
their move-to variants, column widths (Mod+R, Mod+F, Mod+Shift+F), screenshots
(Print, Mod+Print), and the XF86 volume/brightness keys with
`allow-when-locked` where present.

The VRR line (commented out today) is preserved as a Nix `#` comment on the
relevant `outputs."eDP-1"` attr.

## Consequences

- `~/.config/niri/config.kdl` becomes a read-only symlink into `/nix/store`.
  Live-editing that file no longer works; config changes go through Nix and
  require an HM rebuild.
- The settings attrset is type-checked by niri-flake's schema. Typos or
  unknown options fail at evaluation time instead of at niri startup.

## Migration & validation

1. Add `niri-flake` input to `flake.nix`; allow `flake.lock` to populate on
   first build.
2. Rewrite `modules/home-manager/linux/niri.nix` per the shape above.
3. Delete `modules/home-manager/linux/niri/config.kdl` and the now-empty
   `niri/` directory.
4. `sudo nixos-rebuild switch --flake .#naptop`.

**Validation gates:**

- `nix flake check` passes (niri-flake schema rejects typos).
- Rebuild succeeds with no "unknown niri option" warnings.
- `diff` today's `config.kdl` against the generated
  `~/.config/niri/config.kdl` (under /nix/store). Semantic equivalence is
  expected; whitespace and ordering will differ.
- Live-test: `Mod+D` opens fuzzel, touchpad feel matches
  (accel-speed −0.3, scroll-factor 0.5), a screenshot works.

**Rollback:** `git revert` the migration commit restores the symlinked
`config.kdl`. NixOS generation rollback
(`nixos-rebuild switch --rollback`) is also available.
