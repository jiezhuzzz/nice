# Repo Simplification & Restructure — Design

**Date:** 2026-07-06
**Status:** Approved (deeper restructure, curated bundles)

## Goal

Remove the structural duplication that has accumulated across profiles, make
every "add a tool / add a secret / add a host" change a single-file edit, and
delete dead code — while proving, via derivation-hash comparison, that no
machine's configuration changes except where explicitly intended.

## Findings driving the design

1. **Profile duplication.** `profiles/darwin-desktop.nix` and
   `profiles/nixos-desktop.nix` each carry a ~90-line near-identical block:
   a 30-entry HM module import list, six SSH identity blocks, an
   ssh-add-at-login service (launchd vs systemd flavors of the same five-key
   list), and identical home settings (XDG, `CARGO_HOME`, `stateVersion`,
   man caches).
2. **Wiring boilerplate.** `home-manager.useGlobalPkgs` /
   `useUserPackages` / `extraSpecialArgs` repeats in three profiles;
   `import ../users/jie.nix` appears in four files.
3. **Secrets duplication.** `modules/nixos/secrets/default.nix` and
   `modules/nix-darwin/secrets/default.nix` define the same seven secrets,
   differing only by `group = "users"` on NixOS.
4. **Dead code / drift.** `modules/nixos/desktop/gnome.nix` is imported by
   nothing; `login.nix` duplicates its GSettings overrides (possibly inert —
   GNOME itself is disabled); flake.nix's devShell is commented out while
   CLAUDE.md documents it; commented-out leftovers in `codex.nix` and the
   homebrew casks.
5. **Inconsistency.** Some leaf modules are `default.nix`-only directories
   (`nix-darwin/fonts/`, `system/`, `secrets/`), others plain files, with no
   rule.

## Design

### 1. Enriched `lib/mk-hosts.nix`

The factory becomes the single place for platform plumbing:

- Inject `user` (from `users/jie.nix`) into `specialArgs` and
  `extraSpecialArgs` for system and home-manager layers on all three
  builders (`mkNixos`, `mkDarwin`, `mkHome`).
- Set HM wiring once (`useGlobalPkgs`, `useUserPackages`,
  `extraSpecialArgs`, `sharedModules`) for NixOS and darwin builders.
- Profiles stop importing `users/jie.nix` and stop repeating HM wiring.
  `nixpkgs.config.allowUnfree` and the flakes `experimental-features`
  setting move into the builders too (every config sets them today).
  `profiles/homelab.nix` remains as a slim system-side wrapper whose only
  job is pointing `home-manager.users.<user>` at the server bundle.

Foreign hosts (chameleon/goku/vegeta) keep overriding
`home.username`/`homeDirectory` — the injected `user` is a default, not a
mandate.

### 2. Curated HM bundles under `profiles/home/`

Three explicit aggregators (curated, greppable — no readDir magic):

- **`core.nix`** — the ~25 modules every machine shares (theme, atuin,
  direnv, git, ssh, delta, gh, gitui, helix, yazi, zellij, eza, fzf, fd,
  ripgrep, bat, zoxide, bottom, fastfetch, claude-code, codex, uv, npm,
  bun, packages, aliases) plus the shared home settings
  (`preferXdgDirectories`, `xdg.enable`, `CARGO_HOME`,
  `programs.man.generateCaches = false`, `programs.home-manager.enable`,
  `stateVersion = "26.05"`).
- **`desktop.nix`** — imports `core.nix`; adds fish, zed, rime, ghostty,
  rclone, the SSH identity module, and the ssh-add-at-login service. The
  launchd/systemd split lives here behind `pkgs.stdenv.isDarwin`, sharing
  one agenix key-path list.
- **`server.nix`** — imports `core.nix`; adds bash, oh-my-posh, tmux,
  rclone, shpool, and the forwarded-agent stable-socket trick. Used by
  chameleon/goku/vegeta and the homelab wiring. (Replaces today's
  `profiles/server.nix`.)

System-side profiles (`darwin-desktop.nix`, `nixos-desktop.nix`) keep only
genuinely platform-specific system config plus a one-line bundle reference.
Explicit `home.username`/`homeDirectory` lines are dropped where
home-manager derives them from the OS user entry (verified by hash, not
assumed).

The six SSH identity blocks move to a shared module
(`modules/home-manager/common/ssh-identities.nix`), imported by
`desktop.nix` only.

### 3. Single source of truth for secrets

Secret definitions (name → file/owner/mode) move to one shared list in
`secrets/definitions.nix`. The NixOS and darwin secrets modules map over
it, with NixOS adding its `group = "users"`. Adding a secret = one edit.

### 4. Deletions and drift fixes

- Delete `modules/nixos/desktop/gnome.nix`.
- Resolve the `login.nix` GSettings duplicate empirically: remove it; if
  the nixps toplevel hash is unchanged it was inert (stay removed),
  otherwise restore with a comment explaining what consumes it.
- Restore the flake devShell (nil + alejandra) so CLAUDE.md is true again.
  Suggest (not create) a `use flake` `.envrc`.
- Remove commented-out leftovers in `codex.nix` (verify the superpowers
  reference is unused first) and the homebrew cask list (or annotate why
  `"zed"` is parked).
- Flatten `default.nix`-only leaf directories to plain files
  (`nix-darwin/fonts`, `system`, `secrets`; keep composite directories like
  `nixos/desktop/`, `nixos/media/` as directories). Convention going
  forward: files for leaves, directories for composites.
- Route remaining hardcoded `"jie"` / `"frappe"` literals in modules
  through the injected `user`.

### 5. Verification

Baseline drv hashes are captured (2026-07-06, clean tree at 863e8cd):

| Configuration | Baseline drv |
|---|---|
| nixps toplevel | `pkw4g6fms83sslv066zhp24kczmi85gk` |
| nixmachine toplevel | `22v4vhpk8as64f1y1jy0i2vwjcc5a67j` |
| chameleon activation | `g1x0hwqnwwxfk8vcd9rgjwdji8d3f9ya` |
| goku activation | `9l08lqld4icr7vv9115fcwwq4rqwd6z8` |
| vegeta activation | `llzvr1fvj789v842ykg0pbx70fiixwkd` |

- After each implementation step, re-eval these five: hashes must be
  identical except for the explicitly intended deltas in §4 (each such
  delta is inspected and explained when it appears).
- Darwin configs cannot be instantiated from this x86_64-linux box (their
  eval hits a to-be-built dependency); verify instead by diffing
  `nix eval --json` slices before/after: `programs.ssh.settings`,
  `launchd.agents`, `home.sessionVariables`, `home.packages` (names),
  `age.secrets`, `system.primaryUser`.
- Finish with `nix flake check` and `nix fmt` (no diff after formatting).

## Out of scope

- No new flake inputs (no import-tree, easy-hosts, etc.).
- No behavior changes beyond the §4 deletions.
- No changes to `modules/nixos/media/`, `llm/`, `gaming.nix` service logic
  (the repeated LAN-CIDR firewall literal is noted but left as-is — each
  service owning its rule is acceptable).
