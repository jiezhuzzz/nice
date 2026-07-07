# Repo Simplification & Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deduplicate the profile layer into curated home-manager bundles, centralize platform plumbing in `lib/mk-hosts.nix`, unify secrets definitions, and delete dead code — with derivation-hash proof that no machine's config changes except where intended.

**Architecture:** Three HM bundles (`profiles/home/{core,desktop,server}.nix`) replace copy-pasted module lists; the flake builders inject `user` and HM wiring so profiles contain only platform-specific config; a single `secrets/definitions.nix` feeds both platform secrets modules.

**Tech Stack:** Nix flakes, flake-parts, home-manager, nix-darwin, agenix. Verification via `nix eval .#<attr>.drvPath`.

**Spec:** `docs/superpowers/specs/2026-07-06-repo-simplification-design.md`

---

## Ground rules for every task

- Work on branch `chore/simplify-repo`.
- **Flakes only see git-tracked files.** After creating/moving any file, run `git add -A` before any `nix eval`, or the eval silently uses the old tree.
- **The hash check** (run after every task; referred to as VERIFY below):

```bash
cd /home/jie/Repos/nice && git add -A && for attr in \
  nixosConfigurations.nixps.config.system.build.toplevel \
  nixosConfigurations.nixmachine.config.system.build.toplevel \
  homeConfigurations.chameleon.activationPackage \
  homeConfigurations.goku.activationPackage \
  homeConfigurations.vegeta.activationPackage; do
  printf '%s ' "$attr"; nix eval ".#$attr.drvPath" --raw --no-warn-dirty; echo
done
```

Expected output (identical every time, unless a task says otherwise):

```
nixosConfigurations.nixps.config.system.build.toplevel /nix/store/pkw4g6fms83sslv066zhp24kczmi85gk-nixos-system-nixps-26.11.20260628.e1c1b84.drv
nixosConfigurations.nixmachine.config.system.build.toplevel /nix/store/22v4vhpk8as64f1y1jy0i2vwjcc5a67j-nixos-system-nixmachine-26.11.20260628.e1c1b84.drv
homeConfigurations.chameleon.activationPackage /nix/store/g1x0hwqnwwxfk8vcd9rgjwdji8d3f9ya-home-manager-generation.drv
homeConfigurations.goku.activationPackage /nix/store/9l08lqld4icr7vv9115fcwwq4rqwd6z8-home-manager-generation.drv
homeConfigurations.vegeta.activationPackage /nix/store/llzvr1fvj789v842ykg0pbx70fiixwkd-home-manager-generation.drv
```

If a hash differs unexpectedly: STOP, diagnose with `nix-diff` or by reverting the last edit, fix, re-verify. Never commit a task with an unexplained hash change.

- Darwin configs cannot be instantiated on this x86_64-linux box; they are verified via JSON slices (Task 0 captures the baseline, Task 8 compares).
- Scratch dir for slice files: `/tmp/claude-code-jie/claude-1000/-home-jie-Repos-nice/dd89235e-d5ae-415f-a99e-3023ccc5a9ec/scratchpad`

---

### Task 0: Re-verify baseline + capture darwin slices

**Files:** none modified.

- [ ] **Step 0.1:** Run VERIFY. Expected: exactly the baseline table above (proves the docs-only commit didn't shift hashes).

- [ ] **Step 0.2:** Capture darwin baseline slices (all three hosts):

```bash
SCRATCH=/tmp/claude-code-jie/claude-1000/-home-jie-Repos-nice/dd89235e-d5ae-415f-a99e-3023ccc5a9ec/scratchpad
for H in nixair nixmini nixneo; do
  for slice in \
    'home-manager.users.jie.programs.ssh.settings' \
    'home-manager.users.jie.launchd.agents' \
    'home-manager.users.jie.home.sessionVariables' \
    'age.secrets' \
    'system.primaryUser' \
    'homebrew.casks'; do
    out="$SCRATCH/base-$H-$(echo "$slice" | tr '.' '_').json"
    nix eval --json --no-warn-dirty ".#darwinConfigurations.$H.config.$slice" > "$out" 2>"$out.err" || echo "SLICE FAILED (note + skip): $H $slice"
  done
  nix eval --json --no-warn-dirty ".#darwinConfigurations.$H.config.home-manager.users.jie.home.packages" \
    --apply 'ps: map (p: p.name) ps' > "$SCRATCH/base-$H-packages.json" 2>/dev/null || echo "SLICE FAILED: $H packages"
done
```

Expected: JSON files written. Any slice that fails to eval is noted and excluded from the final comparison (it must then fail identically in Task 8).

---

### Task 1: Shared SSH-identities module

**Files:**
- Create: `modules/home-manager/common/ssh-identities.nix`
- Modify: `profiles/darwin-desktop.nix` (delete lines 99–148: the six `programs.ssh.settings` blocks + `launchd.agents.ssh-add-keys`, replace with one import)
- Modify: `profiles/nixos-desktop.nix` (delete lines 101–143: same blocks + `systemd.user.services.ssh-add-keys`)

- [ ] **Step 1.1:** Create `modules/home-manager/common/ssh-identities.nix`:

```nix
# SSH identity pinning + agent auto-load for personal desktop machines.
# Keys are decrypted by agenix to /run/agenix/ (see the platform secrets
# modules); this pins each destination to its key and loads the whole set
# into the agent at login (launchd on macOS, systemd on Linux).
{
  lib,
  pkgs,
  ...
}: let
  keys = [
    "/run/agenix/github-ssh-key"
    "/run/agenix/git-signing-key"
    "/run/agenix/chameleon-ssh-key"
    "/run/agenix/lab-ssh-key"
    "/run/agenix/home-ssh-key"
  ];
in {
  programs.ssh.settings."github.com" = {
    IdentityFile = "/run/agenix/github-ssh-key";
    IdentitiesOnly = true;
  };
  programs.ssh.settings."tacc" = {
    IdentityFile = "/run/agenix/chameleon-ssh-key";
    IdentitiesOnly = true;
  };
  programs.ssh.settings."10.52.*.*" = {
    IdentityFile = "/run/agenix/chameleon-ssh-key";
    IdentitiesOnly = true;
  };
  programs.ssh.settings."uchicago" = {
    HostName = "linux.cs.uchicago.edu";
    User = "jiezhu";
    IdentityFile = "/run/agenix/lab-ssh-key";
    IdentitiesOnly = true;
    ForwardAgent = true;
  };
  programs.ssh.settings."goku vegeta" = {
    ProxyJump = "uchicago";
    User = "jiezzz";
    IdentityFile = "/run/agenix/lab-ssh-key";
    IdentitiesOnly = true;
    ForwardAgent = true;
  };
  programs.ssh.settings."192.168.86.*" = {
    User = "jie";
    IdentityFile = "/run/agenix/home-ssh-key";
    IdentitiesOnly = true;
    ForwardAgent = true;
  };

  launchd.agents.ssh-add-keys = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "com.user.ssh-add-keys";
      ProgramArguments = ["/usr/bin/ssh-add"] ++ keys;
      RunAtLoad = true;
    };
  };

  systemd.user.services.ssh-add-keys = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Load SSH keys into agent";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.openssh}/bin/ssh-add ${lib.concatStringsSep " " keys}";
    };
    Install.WantedBy = ["default.target"];
  };
}
```

**Fallback:** if VERIFY later errors with `The option 'launchd' does not exist` (Linux) or the systemd assertion fires on darwin slice eval, replace the two `mkIf` blocks with eval-level exclusion:

```nix
}
// lib.optionalAttrs pkgs.stdenv.isDarwin {
  launchd.agents.ssh-add-keys = { <same body, no mkIf> };
}
// lib.optionalAttrs pkgs.stdenv.isLinux {
  systemd.user.services.ssh-add-keys = { <same body, no mkIf> };
}
```

- [ ] **Step 1.2:** In `profiles/darwin-desktop.nix`, delete everything from the comment `# SSH identity pinning (keys decrypted by agenix to /run/agenix/)` through the end of the `launchd.agents.ssh-add-keys` block (inclusive), and add `../modules/home-manager/common/ssh-identities.nix` as the last entry of the `# common` section of the HM imports list (after `ghostty`).

- [ ] **Step 1.3:** Same in `profiles/nixos-desktop.nix`: delete from the `# SSH identity pinning` comment through the end of `systemd.user.services.ssh-add-keys`, add the same import after `ghostty`.

- [ ] **Step 1.4:** Run VERIFY. Expected: baseline hashes, unchanged. (nixps is the canary: its HM config must be bit-identical.)

- [ ] **Step 1.5:** Commit:

```bash
git add -A && git commit -m "chore(profiles): extract shared ssh identity pinning into a module"
```

---

### Task 2: Curated home bundles

**Files:**
- Create: `profiles/home/core.nix`, `profiles/home/desktop.nix`
- Move: `profiles/server.nix` → `profiles/home/server.nix` (adjust relative paths, gut the parts core.nix takes over)
- Modify: `profiles/darwin-desktop.nix`, `profiles/nixos-desktop.nix` (HM block shrinks to bundle + platform extras), `profiles/homelab.nix`, `hosts/foreign/{chameleon,goku,vegeta}/default.nix` (import path)

- [ ] **Step 2.1:** Create `profiles/home/core.nix`:

```nix
# profiles/home/core.nix
# CLI toolkit + home settings shared by every machine (desktop and server).
{config, ...}: {
  imports = [
    ../../modules/home-manager/common/packages.nix
    ../../modules/home-manager/common/aliases.nix
    ../../modules/home-manager/common/theme.nix
    ../../modules/home-manager/common/helix.nix
    ../../modules/home-manager/common/yazi.nix
    ../../modules/home-manager/common/atuin.nix
    ../../modules/home-manager/common/direnv.nix
    ../../modules/home-manager/common/git.nix
    ../../modules/home-manager/common/ssh.nix
    ../../modules/home-manager/common/eza.nix
    ../../modules/home-manager/common/fzf.nix
    ../../modules/home-manager/common/zellij.nix
    ../../modules/home-manager/common/zoxide.nix
    ../../modules/home-manager/common/fd.nix
    ../../modules/home-manager/common/fastfetch.nix
    ../../modules/home-manager/common/bat.nix
    ../../modules/home-manager/common/bun.nix
    ../../modules/home-manager/common/gitui.nix
    ../../modules/home-manager/common/bottom.nix
    ../../modules/home-manager/common/ripgrep.nix
    ../../modules/home-manager/common/claude-code.nix
    ../../modules/home-manager/common/codex.nix
    ../../modules/home-manager/common/uv.nix
    ../../modules/home-manager/common/npm.nix
    ../../modules/home-manager/common/delta.nix
    ../../modules/home-manager/common/gh.nix
  ];

  home.preferXdgDirectories = true;
  xdg.enable = true;
  home.sessionVariables.CARGO_HOME = "${config.xdg.dataHome}/cargo";
  programs.man.generateCaches = false;
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
}
```

- [ ] **Step 2.2:** Create `profiles/home/desktop.nix`:

```nix
# profiles/home/desktop.nix
# Home config for personal desktop machines (macOS and NixOS).
{
  imports = [
    ./core.nix
    ../../modules/home-manager/common/fish.nix
    ../../modules/home-manager/common/zed.nix
    ../../modules/home-manager/common/rime.nix
    ../../modules/home-manager/common/ghostty
    ../../modules/home-manager/common/ssh-identities.nix
  ];
}
```

- [ ] **Step 2.3:** `git mv profiles/server.nix profiles/home/server.nix`, then rewrite it as:

```nix
# profiles/home/server.nix
# Home config for headless machines: standalone HM on foreign servers
# (chameleon/goku/vegeta) and, via profiles/homelab.nix, NixOS homelab boxes.
{
  imports = [
    ./core.nix
    ../../modules/home-manager/common/bash.nix
    ../../modules/home-manager/common/oh-my-posh.nix
    ../../modules/home-manager/common/tmux.nix
    ../../modules/home-manager/common/rclone.nix
    ../../modules/home-manager/linux/shpool.nix
  ];

  # Pin a forwarded SSH agent to a stable socket so tmux survives detach/
  # reconnect. With ForwardAgent each connection gets a fresh per-connection
  # $SSH_AUTH_SOCK that dies on disconnect; long-lived tmux panes capture the
  # original value and end up pointing at a dead socket. The login shell
  # repoints ~/.ssh/agent.sock at the live socket (.profile runs before .bashrc,
  # so it still sees the real socket), and every shell uses that stable path —
  # so even already-running panes transparently follow the refreshed link.
  # Kept in this profile (not a shared module): only standalone servers get a
  # forwarded agent.
  programs.bash = {
    profileExtra = ''
      if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock" ]; then
        ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
      fi
    '';
    bashrcExtra = ''
      [ -S "$HOME/.ssh/agent.sock" ] && export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    '';
  };
}
```

(The `{config, ...}:` header, XDG/CARGO/stateVersion/man/home-manager lines are gone — core.nix owns them. The module now takes no args: plain attrset.)

- [ ] **Step 2.4:** In `profiles/darwin-desktop.nix`, replace the whole `home-manager.users.${user.me.username} = {config, ...}: { imports = [ ...30 lines... ]; home.username = ...; ... }` block's imports + settings with:

```nix
  home-manager.users.${user.me.username} = {
    imports = [
      ./home/desktop.nix
      ../modules/home-manager/common/rclone.nix
      ../modules/home-manager/darwin/aerospace.nix
      ../modules/home-manager/darwin/karabiner.nix
      ../modules/home-manager/darwin/zotero.nix
      ../modules/home-manager/darwin/packages.nix
    ];
  };
```

Notes: `rclone.nix` stays darwin-only here (nixos-desktop never had it — adding it to the bundle would change nixps's closure). `home.username`/`home.homeDirectory` are dropped: the nix-darwin HM module derives them from `users.users.jie` (uid 501, home `/Users/jie`, both still declared in this profile). The `{config, ...}:` function header goes away (no more `config` use).

- [ ] **Step 2.5:** In `profiles/nixos-desktop.nix`, same surgery:

```nix
  home-manager.users.${user.me.username} = {pkgs, ...}: {
    imports = [
      ./home/desktop.nix
      ../modules/home-manager/linux/packages.nix
      ../modules/home-manager/linux/niri.nix
      ../modules/home-manager/linux/ghostty.nix
      ../modules/home-manager/linux/shpool.nix
    ];

    home.pointerCursor = {
      name = "Banana";
      package = pkgs.banana-cursor;
      size = 32;
      gtk.enable = true;
    };
  };
```

(`home.username`/`homeDirectory` dropped — derived from `users.users.jie` on NixOS.)

- [ ] **Step 2.6:** Update importers of the moved server profile:
  - `profiles/homelab.nix`: `imports = [./server.nix];` → `imports = [./home/server.nix];`
  - `hosts/foreign/chameleon/default.nix`, `hosts/foreign/goku/default.nix`, `hosts/foreign/vegeta/default.nix`: `../../../profiles/server.nix` → `../../../profiles/home/server.nix`

- [ ] **Step 2.7:** Run VERIFY. Expected: baseline hashes, unchanged. If nixps differs, the likely cause is the dropped `home.username`/`homeDirectory` (means they are NOT derived) — restore those two lines in the profile and re-verify.

- [ ] **Step 2.8:** Commit:

```bash
git add -A && git commit -m "chore(profiles): fold hm module lists into curated home bundles"
```

---

### Task 3: Centralize plumbing in mk-hosts builders

**Files:**
- Modify: `lib/mk-hosts.nix` (full rewrite below)
- Modify: `profiles/darwin-desktop.nix`, `profiles/nixos-desktop.nix`, `profiles/homelab.nix` (drop `let user = import …`, HM wiring, allowUnfree/experimental-features; take `user` as arg)
- Modify: `modules/home-manager/common/theme.nix`, `hosts/nixos/nixmachine/default.nix` (use `user` arg)

- [ ] **Step 3.1:** Rewrite `lib/mk-hosts.nix`:

```nix
# flake-parts module that declares flake.nixosConfigurations,
# flake.darwinConfigurations, flake.homeConfigurations.
#
# The builders own all cross-cutting plumbing: `inputs` + `user` in every
# layer's specialArgs, home-manager wiring for the system builders, and the
# settings every machine sets (allowUnfree; flakes on NixOS). Profiles and
# hosts only describe what is specific to them.
{inputs, ...}: let
  user = import ../users/jie.nix;

  # HM module injected into every home-manager user, however it is wired in.
  hmSharedModules = [inputs.catppuccin.homeModules.catppuccin];

  # home-manager wiring shared by the NixOS and darwin system builders.
  hmSystemWiring = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {inherit inputs user;};
      sharedModules = hmSharedModules;
    };
  };

  mkNixos = modules:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs user;};
      modules =
        modules
        ++ [
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.agenix.nixosModules.default
          hmSystemWiring
          {
            nixpkgs.config.allowUnfree = true;
            nix.settings.experimental-features = ["nix-command" "flakes"];
          }
        ];
    };

  mkDarwin = modules:
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = {inherit inputs user;};
      modules =
        modules
        ++ [
          inputs.home-manager.darwinModules.home-manager
          hmSystemWiring
          {nixpkgs.config.allowUnfree = true;}
        ];
    };

  mkHome = system: modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = {inherit inputs user;};
      modules = modules ++ hmSharedModules;
    };
in {
  flake.nixosConfigurations = {
    nixps = mkNixos [../hosts/nixos/nixps];
    nixmachine = mkNixos [../hosts/nixos/nixmachine];
  };

  flake.homeConfigurations = {
    chameleon = mkHome "x86_64-linux" [../hosts/foreign/chameleon];
    goku = mkHome "x86_64-linux" [../hosts/foreign/goku];
    vegeta = mkHome "x86_64-linux" [../hosts/foreign/vegeta];
  };

  flake.darwinConfigurations = {
    nixmini = mkDarwin [../hosts/macos/nixmini.nix];
    nixair = mkDarwin [../hosts/macos/nixair.nix];
    nixneo = mkDarwin [../hosts/macos/nixneo.nix];
  };
}
```

(Note: darwin gets NO `nix.settings.experimental-features` — `nix.enable = false` on darwin forbids nix-darwin managing nix settings. agenix's darwin module moves into `mkDarwin` in Task 5, together with removing it from the secrets module — not here, to avoid a double import.)

- [ ] **Step 3.2:** `profiles/darwin-desktop.nix` header + wiring: change the function header to `{ inputs, pkgs, user, ... }:` and delete the `let user = import ../users/jie.nix; in`; delete `nixpkgs.config.allowUnfree = true;`; delete the three lines `home-manager.useGlobalPkgs`, `home-manager.useUserPackages`, `home-manager.extraSpecialArgs`.

- [ ] **Step 3.3:** `profiles/nixos-desktop.nix`: same — header `{ inputs, pkgs, user, ... }:`, drop the `let user … in`, drop `nixpkgs.config.allowUnfree`, drop `nix.settings.experimental-features`, drop the three `home-manager.*` wiring lines. Keep `catppuccin.enable/autoEnable/flavor` (now `user.theme.flavor` resolves via the arg).

- [ ] **Step 3.4:** Rewrite `profiles/homelab.nix`:

```nix
# profiles/homelab.nix
# Lean, headless NixOS profile for homelab boxes (e.g. nixmachine): user
# `jie` gets the exact same home-manager toolkit as the standalone servers
# (profiles/home/server.nix), wired through the NixOS home-manager module so
# the two never drift. Boot, storage, networking and the user account stay
# with the host.
{user, ...}: {
  home-manager.users.${user.me.username}.imports = [./home/server.nix];
}
```

- [ ] **Step 3.5:** `modules/home-manager/common/theme.nix` — take `user` from module args instead of re-importing:

```nix
{user, ...}: {
  catppuccin.enable = true;
  catppuccin.autoEnable = true;
  catppuccin.flavor = user.theme.flavor;
}
```

- [ ] **Step 3.6:** `hosts/nixos/nixmachine/default.nix` — change header from `{ inputs, lib, pkgs, ... }: let user = import ../../../users/jie.nix; in {` to `{ inputs, lib, pkgs, user, ... }: {`; delete the comment lines `# nixpkgs.config.allowUnfree and nix.settings.experimental-features are set` / `# by the homelab profile.` (now set by the builder).

- [ ] **Step 3.7:** Run VERIFY. Expected: baseline hashes, unchanged. If homelab's dropped `home.username`/`homeDirectory` shifts nixmachine's hash, restore those two lines inside the `home-manager.users.…` attrset in homelab.nix and re-verify.

- [ ] **Step 3.8:** Commit:

```bash
git add -A && git commit -m "chore(flake): centralize user + hm wiring in the mk-hosts builders"
```

---

### Task 4: Flatten default.nix-only leaf directories

**Files (git mv, content untouched):**
- `modules/nix-darwin/fonts/default.nix` → `modules/nix-darwin/fonts.nix`
- `modules/nix-darwin/homebrew/default.nix` → `modules/nix-darwin/homebrew.nix`
- `modules/nix-darwin/secrets/default.nix` → `modules/nix-darwin/secrets.nix`
- `modules/nix-darwin/system/default.nix` → `modules/nix-darwin/system.nix`
- `modules/nixos/boot/default.nix` → `modules/nixos/boot.nix`
- `modules/nixos/secrets/default.nix` → `modules/nixos/secrets.nix`
- Modify importers: `profiles/darwin-desktop.nix`, `profiles/nixos-desktop.nix`
- Keep as directories (composites/assets): `nixos/{desktop,hardware,media,llm}`, `home-manager/common/ghostty` (holds `shaders/`)

- [ ] **Step 4.1:** Move the six files:

```bash
cd /home/jie/Repos/nice
for m in nix-darwin/fonts nix-darwin/homebrew nix-darwin/secrets nix-darwin/system nixos/boot nixos/secrets; do
  git mv "modules/$m/default.nix" "modules/$m.nix" && rmdir "modules/$m" 2>/dev/null || true
done
```

- [ ] **Step 4.2:** Fix the relative-path depth inside the two moved secrets files (they are now one level shallower): in `modules/nix-darwin/secrets.nix` and `modules/nixos/secrets.nix`, replace every `../../../users/jie.nix` with `../../users/jie.nix` and every `../../../secrets/` with `../../secrets/`. (These files get fully rewritten in Task 5 anyway; this keeps Task 4 independently green.)

- [ ] **Step 4.3:** Update importers — `profiles/darwin-desktop.nix`:

```nix
  imports = [
    ../modules/nix-darwin/fonts.nix
    ../modules/nix-darwin/homebrew.nix
    ../modules/nix-darwin/secrets.nix
    ../modules/nix-darwin/system.nix
  ];
```

`profiles/nixos-desktop.nix`:

```nix
  imports = [
    ../modules/nixos/boot.nix
    ../modules/nixos/hardware
    ../modules/nixos/desktop
    ../modules/nixos/secrets.nix
  ];
```

- [ ] **Step 4.4:** Run VERIFY. Expected: baseline hashes, unchanged.

- [ ] **Step 4.5:** Commit:

```bash
git add -A && git commit -m "chore(modules): flatten default.nix-only leaf modules to plain files"
```

---

### Task 5: Single secrets definition list

**Files:**
- Create: `secrets/definitions.nix`
- Rewrite: `modules/nixos/secrets.nix`, `modules/nix-darwin/secrets.nix`
- Modify: `lib/mk-hosts.nix` (add agenix darwin module to `mkDarwin`)

- [ ] **Step 5.1:** Create `secrets/definitions.nix`:

```nix
# One entry per agenix secret: name → encrypted source file. Consumed by the
# platform secrets modules (modules/nixos/secrets.nix and
# modules/nix-darwin/secrets.nix), which decrypt each to /run/agenix/<name>.
# Recipients for the .age files live in ./secrets.nix (agenix CLI manifest).
{
  github-ssh-key = ./ssh/github.age;
  git-signing-key = ./ssh/git-signing.age;
  chameleon-ssh-key = ./ssh/chameleon.age;
  lab-ssh-key = ./ssh/lab.age;
  home-ssh-key = ./ssh/home.age;
  rclone-gdrive-token = ./rclone/gdrive.age;
  rclone-box-token = ./rclone/box.age;
}
```

- [ ] **Step 5.2:** Rewrite `modules/nixos/secrets.nix`:

```nix
# age-encrypted secrets decrypted at activation time using the host's
# SSH host key (see age.identityPaths). Each secret lands at
# /run/agenix/<name> with the owner/mode specified here.
{user, ...}: {
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets =
    builtins.mapAttrs (_: file: {
      inherit file;
      owner = user.me.username;
      group = "users";
      mode = "0400";
    })
    (import ../../secrets/definitions.nix);
}
```

- [ ] **Step 5.3:** Rewrite `modules/nix-darwin/secrets.nix` (agenix module import moves to the builder in the next step; darwin has no `group`):

```nix
# age-encrypted secrets decrypted at activation time using the host's
# SSH host key (see age.identityPaths). Each secret lands at
# /run/agenix/<name> with the owner/mode specified here.
{user, ...}: {
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets =
    builtins.mapAttrs (_: file: {
      inherit file;
      owner = user.me.username;
      mode = "0400";
    })
    (import ../../secrets/definitions.nix);
}
```

- [ ] **Step 5.4:** In `lib/mk-hosts.nix`, add `inputs.agenix.darwinModules.default` to `mkDarwin`'s injected modules (after `inputs.home-manager.darwinModules.home-manager`), mirroring `mkNixos`.

- [ ] **Step 5.5:** Run VERIFY. Expected: baseline hashes, unchanged (same .age paths → same store paths). Also spot-check darwin eval still works:

```bash
nix eval --json --no-warn-dirty '.#darwinConfigurations.nixair.config.age.secrets' | head -c 400
```

Expected: JSON with the seven secrets, `file` pointing at the same store paths as the Task 0 baseline slice.

- [ ] **Step 5.6:** Commit:

```bash
git add -A && git commit -m "chore(secrets): single definitions list consumed by both platforms"
```

---

### Task 6: Dead code removal

**Files:**
- Delete: `modules/nixos/desktop/gnome.nix`
- Modify: `modules/nixos/desktop/login.nix` (empirical), `modules/home-manager/common/codex.nix`, `modules/nix-darwin/homebrew.nix`

- [ ] **Step 6.1:** `git rm modules/nixos/desktop/gnome.nix` (byte-identical to login.nix, imported by nothing — `modules/nixos/desktop/default.nix` lists only login/niri/input-method/fonts/xremap/1password).

- [ ] **Step 6.2 (empirical test):** In `modules/nixos/desktop/login.nix`, delete the whole `services.desktopManager.gnome.extraGSettingsOverrides = ''…'';` block and the two comment lines above it (`# GNOME desktop disabled…` / `# services.desktopManager.gnome.enable = true;` and `# Fractional scaling…`), leaving:

```nix
_: {
  services.displayManager.gdm.enable = true;
}
```

- [ ] **Step 6.3:** Run VERIFY and compare nixps only.
  - If nixps hash **unchanged** → the overrides were inert (GNOME disabled); keep the deletion.
  - If nixps hash **changed** → something (gdm greeter) consumes them: `git checkout -- modules/nixos/desktop/login.nix`, then re-apply only the removal of the stale `# services.desktopManager.gnome.enable = true;` comment line and add above the overrides block: `# Consumed by the GDM greeter session even with GNOME disabled.` Re-run VERIFY (hash must then be back at baseline… plus note that comment-only edits never change hashes).

- [ ] **Step 6.4:** Commit:

```bash
git add -A && git commit -m "chore(nixos): drop dead gnome module and inert gsettings overrides"
```

(Adjust the message to `chore(nixos): drop dead gnome desktop module` if 6.3 took the restore path.)

- [ ] **Step 6.5:** `modules/home-manager/common/codex.nix`: delete the `superpowers = pkgs.fetchFromGitHub { … };` let-binding (lines 7–13) and the commented line `# "superpowers" = "${superpowers}/skills";` (line 65). Both are dead — the only references to `superpowers` in the file are these two spots (verified by grep; superpowers now comes from the Claude plugin ecosystem, not this fetch).

- [ ] **Step 6.6:** Run VERIFY. Expected: baseline (the binding was eval-only and unused). Commit:

```bash
git add -A && git commit -m "chore(home-manager): drop unused superpowers fetch from codex module"
```

- [ ] **Step 6.7:** `modules/nix-darwin/homebrew.nix`: delete the line `#"zed"` (zed is managed by the HM module `common/zed.nix`; the cask stays intentionally absent). Commit:

```bash
git add -A && git commit -m "chore(darwin): drop commented-out zed cask"
```

---

### Task 7: Dev shell + docs sync

**Files:**
- Modify: `flake.nix` (restore devShell), `CLAUDE.md` (architecture section)

- [ ] **Step 7.1:** In `flake.nix` `perSystem`, replace the commented block with:

```nix
        devShells.default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            nil
            alejandra
          ];
        };
```

- [ ] **Step 7.2:** Verify: `nix develop --no-warn-dirty -c sh -c 'nil --version && alejandra --version'`. Expected: both print versions.

- [ ] **Step 7.3:** Commit:

```bash
git add -A && git commit -m "chore(flake): restore the nil + alejandra dev shell"
```

- [ ] **Step 7.4:** Update `CLAUDE.md` "Three-Tier Module System" section to match reality:
  - Profiles: `darwin-desktop.nix` / `nixos-desktop.nix` (system-side, platform-specific), `homelab.nix` (headless NixOS wrapper), and `profiles/home/{core,desktop,server}.nix` (curated home-manager bundles; core = shared CLI toolkit, desktop = core + GUI/desktop tools + SSH identities, server = core + headless shell tooling).
  - Note the plumbing rule: `lib/mk-hosts.nix` injects `inputs` + `user` (from `users/jie.nix`) into all layers and owns HM wiring + allowUnfree; profiles/hosts never repeat it.
  - Note the module convention: leaf modules are single `.nix` files; directories only for composites (`nixos/desktop`, `nixos/media`, …) or modules with assets (`ghostty/`).
  - Note secrets: definitions in `secrets/definitions.nix`, recipients in `secrets/secrets.nix`.

- [ ] **Step 7.5:** Commit:

```bash
git add -A && git commit -m "docs(repo): sync CLAUDE.md with the restructured layout"
```

---

### Task 8: Final verification

- [ ] **Step 8.1:** `nix fmt` then `git status --short`. Expected: no modifications (all new code alejandra-clean). If files changed, inspect, then commit: `git add -A && git commit -m "chore(repo): apply nix fmt"`.

- [ ] **Step 8.2:** `nix flake check --no-warn-dirty`. Expected: pass (treefmt check + eval of NixOS configs; darwinConfigurations/homeConfigurations produce "unknown output" warnings — fine).

- [ ] **Step 8.3:** Run VERIFY one last time. Expected: baseline table exactly (Task 6 gsettings removal must NOT have changed nixps — if it did, it was restored in 6.3).

- [ ] **Step 8.4:** Re-capture the darwin slices with the Task 0 command (change filename prefix `base-` → `after-`), then diff:

```bash
SCRATCH=/tmp/claude-code-jie/claude-1000/-home-jie-Repos-nice/dd89235e-d5ae-415f-a99e-3023ccc5a9ec/scratchpad
for f in "$SCRATCH"/base-*.json; do
  after="${f/base-/after-}"
  diff <(jq -S . "$f") <(jq -S . "$after") >/dev/null 2>&1 && echo "OK   $(basename "$f")" || echo "DIFF $(basename "$f")"
done
```

Expected: `OK` for every slice (any slice that failed at Task 0 must fail identically now). A `DIFF` is a stop-and-diagnose.

- [ ] **Step 8.5:** Report: hash table, slice results, commit list (`git log --oneline main..`), and net line delta (`git diff --stat main..`).

---

## Self-review notes

- Spec §1 (builders) → Task 3 + 5.4; §2 (bundles + ssh identities) → Tasks 1–2; §3 (secrets) → Task 5; §4 (deletions/drift/flatten/literals) → Tasks 4, 6, 7 + theme.nix in 3.5; §5 (verification) → Tasks 0, 8 + VERIFY in every task. No spec item unassigned.
- Rollback unit = one task = one commit; every commit leaves the tree green (VERIFY passes).
- Known judgment calls encoded: rclone stays darwin-only (2.4), darwin keeps no `experimental-features` (3.1), agenix darwin module moves in the same commit that stops importing it (5.3–5.4), login.nix decided empirically (6.2–6.3).
