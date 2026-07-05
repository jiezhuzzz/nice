# Steam Gaming Session on nixmachine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `nixmachine` a console-like Steam session — boot straight into gamescope → Steam Big Picture on the AMD GPU via greetd autologin — while its homelab services keep running underneath.

**Architecture:** One self-contained NixOS module (`modules/nixos/gaming.nix`) enables `programs.steam` + its gamescope session, `programs.gamescope`, `programs.gamemode`, and a `greetd` login daemon whose `initial_session` autologins `jie` into the `steam-gamescope` launcher and whose `default_session` drops to an `agreety` text console on exit. The module is imported only by `hosts/nixos/nixmachine/default.nix`; nothing else changes.

**Tech Stack:** NixOS (flake-parts), alejandra formatter, greetd, gamescope, Steam, Mesa/RADV (AMD). No unit-test framework — verification is Nix syntax parse + `nix flake check` + a full system build; behavioral verification is manual on the hardware.

---

## Notes on verification style

This is declarative system config, not application code, so there is no red-green
unit-test loop. The equivalent "tests" are:
1. `nix-instantiate --parse <file>` — the file is valid Nix syntax.
2. `nix flake check` — the flake (all hosts) evaluates.
3. `nix build .#nixosConfigurations.nixmachine.config.system.build.toplevel` — the
   `nixmachine` system closure actually builds.

Facts already verified against the pinned nixpkgs
(`/nix/store/crkjzq0bcp7afqwqdpb9s94nivpgc4qw-source`):
- `programs.steam.gamescopeSession.enable` installs a `steam-gamescope` binary
  onto the system PATH (`environment.systemPackages`), which runs
  `gamescope --steam … -- steam …`.
- `programs.steam.enable` already sets `hardware.steam-hardware.enable = true`
  (controller udev rules) — do **not** set it again.
- `services.greetd.restart` defaults to `!(settings ? initial_session)`, i.e.
  `false` once `initial_session` is set — the autologin fires once, no loop.
- The text greeter binary is `${pkgs.greetd}/bin/agreety` (package is `pkgs.greetd`).
- The homelab profile already sets `nixpkgs.config.allowUnfree = true` (Steam is
  unfree) and `hardware.graphics.enable32Bit = true` is set on the host — no
  changes needed for either.

## File Structure

- **Create:** `modules/nixos/gaming.nix` — the entire gaming feature (Steam +
  gamescope session + gamemode + greetd autologin). Single responsibility:
  "turn nixmachine into a boot-to-Steam console." Flat-file, matching the
  `modules/nixos/stirling-pdf.nix` precedent.
- **Modify:** `hosts/nixos/nixmachine/default.nix` — add one line to `imports`.

---

### Task 1: Create the gaming module

**Files:**
- Create: `modules/nixos/gaming.nix`

- [ ] **Step 1: Write the module file**

Create `modules/nixos/gaming.nix` with exactly this content:

```nix
# modules/nixos/gaming.nix
# Console-like Steam gaming session for nixmachine.
#
# Boots straight into gamescope → Steam Big Picture (SteamOS-style) via greetd
# autologin, on the AMD GPU (Mesa/RADV). The homelab services (media / LLM /
# stirling-pdf / sshd) are independent systemd units and keep running
# underneath — SSH works before, during, and after gaming.
#
# Exit behaviour: quitting Steam ends the gamescope session; greetd then shows a
# plain agreety text login on the monitor (console-blanks on idle). The box is
# functionally headless again — just SSH in as usual.
#
# ⚠️  Steam Big Picture's power menu Shutdown / Restart powers off the WHOLE box,
#     killing the 24/7 homelab services. To return to server mode use Big
#     Picture's plain "Exit" (quit Steam), NOT Shutdown.
{pkgs, ...}: let
  user = import ../../users/jie.nix;
in {
  # Steam + the gamescope "steam" session. programs.steam.enable already turns
  # on hardware.steam-hardware (controller udev rules) and 32-bit audio, and
  # installs the `steam-gamescope` launcher onto the system PATH. Unfree is
  # already allowed by the homelab profile; 32-bit graphics is enabled on the
  # host.
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  # gamescope compositor. capSysNice lets it request realtime priority for
  # smoother frame pacing.
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Performance CPU governor while a game is running.
  programs.gamemode.enable = true;

  # greetd: a minimal login daemon (no graphical greeter). It opens a logind
  # seat session so gamescope can reach the GPU (DRM/KMS) and input devices.
  #   initial_session → runs once at boot: autologin jie straight into Steam.
  #   default_session → shown after Steam exits: a plain text login prompt.
  # Setting initial_session flips services.greetd.restart to false by default,
  # so the autologin fires exactly once (no relaunch loop).
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "steam-gamescope"; # on PATH via programs.steam.gamescopeSession
        user = user.me.username;
      };
      default_session = {
        command = "${pkgs.greetd}/bin/agreety --cmd $SHELL";
        # user defaults to "greeter"
      };
    };
  };
}
```

- [ ] **Step 2: Verify it is valid Nix syntax**

Run: `nix-instantiate --parse modules/nixos/gaming.nix`
Expected: prints the parsed expression (no error). A syntax error would print
`error: syntax error` with a line number.

- [ ] **Step 3: Format**

Run: `nix fmt modules/nixos/gaming.nix`
Expected: alejandra reformats/normalises the file; exits 0.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/gaming.nix
git commit -m "feat(gaming): add steam gamescope console module"
```

---

### Task 2: Enable the module on nixmachine and build the system

**Files:**
- Modify: `hosts/nixos/nixmachine/default.nix` (the `imports` list, currently lines 9-18)

- [ ] **Step 1: Add the module to nixmachine's imports**

In `hosts/nixos/nixmachine/default.nix`, add the gaming module to the `imports`
list. Change:

```nix
    ../../../modules/nixos/stirling-pdf.nix # self-hosted PDF toolkit
    inputs.disko.nixosModules.disko
```

to:

```nix
    ../../../modules/nixos/stirling-pdf.nix # self-hosted PDF toolkit
    ../../../modules/nixos/gaming.nix # console-like Steam gamescope session (local play)
    inputs.disko.nixosModules.disko
```

- [ ] **Step 2: Format**

Run: `nix fmt`
Expected: exits 0; no diff on `hosts/nixos/nixmachine/default.nix` beyond the
added line (already well-formed).

- [ ] **Step 3: Evaluate the flake**

Run: `nix flake check`
Expected: completes with no evaluation errors. (Warnings unrelated to this change
are acceptable.)

- [ ] **Step 4: Build the nixmachine system closure**

Run: `nix build .#nixosConfigurations.nixmachine.config.system.build.toplevel`
Expected: builds to `./result` with no error. This proves Steam, gamescope,
gamemode, and greetd all evaluate and their packages build for `nixmachine`.

If the build fails, read the first error:
- An `agreety`/`greetd` path error → confirm `pkgs.greetd` is correct.
- A `steam-gamescope: command not found` cannot appear at build time (it is a
  runtime PATH lookup) — it surfaces only on the machine (Task 3).
- An unfree error → the homelab profile should already allow unfree; confirm the
  host still imports `profiles/homelab.nix`.

- [ ] **Step 5: Commit**

```bash
git add hosts/nixos/nixmachine/default.nix
git commit -m "feat(gaming): enable steam gaming session on nixmachine"
```

---

### Task 3: On-hardware verification (manual, on nixmachine itself)

This cannot be done from the build host — it requires the physical machine with a
monitor + keyboard (and ideally a controller) attached. Document the outcome; do
not mark the feature done until these pass.

- [ ] **Step 1: Deploy**

On `nixmachine` (or via deploy): `sudo nixos-rebuild switch --flake .#nixmachine`
Expected: activates without error.

- [ ] **Step 2: Reboot and observe boot-to-Steam**

Run: `sudo reboot`
Expected: the monitor comes up directly in **Steam Big Picture** (gamescope),
logged in as `jie`, no login prompt.

- [ ] **Step 3: Confirm the homelab stays headless-independent**

While Steam is running, from another machine: `ssh jie@nixmachine` and check a
service, e.g. `systemctl status jellyfin` (or whatever the media stack exposes).
Expected: SSH works and services are active — gaming did not disturb them.

- [ ] **Step 4: Confirm drop-to-console on exit**

In Steam Big Picture, use the plain **Exit** (quit Steam — NOT the power-menu
Shutdown).
Expected: gamescope closes and the monitor shows a plain `agreety` text login
prompt; SSH and homelab services remain up. Console blanks after the idle
timeout.

- [ ] **Step 5: (Optional) Controller check**

Plug in a controller; confirm Big Picture sees it (steam-hardware udev rules).

- [ ] **Step 6: Record the result**

Note pass/fail for steps 2-4 in the PR / commit message. Only then is the feature
complete.

---

## Self-Review

**Spec coverage:**
- Console-like gamescope → Steam Big Picture → Task 1 (`programs.steam.gamescopeSession`, gamescope). ✓
- AMD/Mesa RADV, no amdvlk, no extra driver → relies on host `hardware.graphics.enable32Bit` (noted, unchanged). ✓
- Auto-login jie → Task 1 greetd `initial_session`. ✓
- greetd, not a display manager → Task 1. ✓
- Drop-to-console on exit → Task 1 greetd `default_session = agreety`; verified Task 3 Step 4. ✓
- GameMode / controllers → Task 1 (`programs.gamemode`; steam-hardware auto via `programs.steam`). ✓
- Big-Picture-Shutdown caveat → documented in the module header + Task 3 Step 4. ✓
- Single module imported only by nixmachine, no profile/other-host changes → Task 2. ✓
- No remote streaming / firewall, no full desktop, no MangoHud/Proton tooling → nothing added (YAGNI). ✓
- Verification: fmt + flake check + build → Task 2; manual boot test → Task 3. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full content; every run
step has an expected result. The one runtime-only item (`steam-gamescope` PATH
lookup) is explicitly called out as verifiable only in Task 3, not left vague.

**Type/name consistency:** `steam-gamescope` (launcher), `pkgs.greetd`/`agreety`,
`user.me.username`, `initial_session`/`default_session`, and the import path
`../../users/jie.nix` (module is two levels deep) are consistent across tasks and
match the verified nixpkgs option names.
