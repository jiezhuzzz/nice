# Steam Gaming Session on nixmachine (Design)

**Status:** approved · **Date:** 2026-07-05 · **Host:** nixmachine

## Problem

`nixmachine` is a lean, headless homelab box (imports `profiles/homelab.nix`)
driven over SSH: no display manager, no compositor, no desktop. It runs a
media/LLM/PDF service stack and has an AMD CPU with the GPU/graphics stack
already enabled (`hardware.graphics.enable{,32Bit}`).

We want to add **local** gaming: attach a monitor/keyboard and boot straight
into a SteamOS-style console session — gamescope running Steam Big Picture on
the AMD GPU — while the homelab services keep running underneath, untouched.

## Decisions (from brainstorming)

- **Play mode:** local gaming desktop (not remote streaming).
- **GPU:** AMD (Radeon / APU) → Mesa/RADV, no proprietary driver, no `amdvlk`.
- **Session:** console-like gamescope → Steam Big Picture. No full desktop
  environment.
- **Boot:** auto-login `jie` straight into the gaming session.
- **Login stack:** **greetd**, not a display manager (GDM/SDDM). We only need a
  logind seat session so gamescope can reach `/dev/dri` (DRM/KMS) and
  `/dev/input`; greetd provides that with no graphical greeter and no
  GNOME/KDE baggage.
- **Exit behavior:** drop to a bare text console. Exiting Steam returns the box
  to a functional headless server (console prompt on the monitor, SSH-only
  otherwise). Not a kiosk loop.

## Non-goals

- No remote streaming (Sunshine/Moonlight/Steam Remote Play), no firewall
  openings — this is local play.
- No full desktop environment; no reuse of `nixos-desktop.nix` / the desktop
  module bundle.
- No proprietary/alternate Vulkan (`amdvlk`) — Mesa RADV is the better default.
- No changes to the homelab profile or any other host. Everything is opt-in via
  a single module imported only by `nixmachine`.
- Optional tooling (MangoHud, ProtonUp-Qt, protontricks) is out of scope for v1;
  trivial to add later.

## Architecture

```
boot
  └─ systemd default target flips to graphical (greetd enabled)
  └─ greetd  (owns the VT / seat0)
       ├─ initial_session  (once, at boot) ── autologin ──▶ jie
       │     command = steam-gamescope   (gamescope --steam -- steam -gamepadui)
       │     → gamescope compositor drives the AMD GPU (DRM/KMS)
       │     → Steam Big Picture
       │
       └─ on session exit (user hits "Exit" in Big Picture):
             default_session  ──▶ agreety text greeter (user "greeter")
             → monitor shows a plain login prompt; console blanks on idle
             → box is functionally headless again; SSH unaffected throughout

homelab services (media / LLM / stirling-pdf / sshd)
  └─ systemd services, independent of the graphical session — run before,
     during, and after gaming. Never touched by Steam start/exit.
```

**Why greetd and not a DM:** gamescope needs non-root access to the GPU and
input devices, which logind grants per-seat. Any PAM login that opens a logind
session on seat0 satisfies this; a graphical greeter is unnecessary. greetd is
the minimal daemon that opens that session and launches one command.

**Why `initial_session` + `default_session`:** greetd runs `initial_session`
exactly once at boot (the autologin into Steam), then falls back to
`default_session` (the text greeter) every time a session ends. So the first
boot goes straight to Steam, and hitting Exit lands on a console — matching the
"back to headless" intent without a kiosk loop.

## Components

### NixOS module — `modules/nixos/gaming.nix`

A single self-contained module (flat-file precedent: `modules/nixos/stirling-pdf.nix`),
imported by `hosts/nixos/nixmachine/default.nix`. Contents:

- **Steam:**
  - `programs.steam.enable = true;`
  - `programs.steam.gamescopeSession.enable = true;` — installs the
    `steam-gamescope` launcher + registers the gamescope session.
  - `hardware.steam-hardware.enable = true;` — udev rules for controllers
    (Steam Controller, Xbox, DualSense, etc.).
- **gamescope:**
  - `programs.gamescope.enable = true;`
  - `programs.gamescope.capSysNice = true;` — lets gamescope request realtime
    priority (smoother frame pacing).
- **GameMode:** `programs.gamemode.enable = true;` — performance CPU governor
  while a game runs.
- **greetd session:**
  ```nix
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "steam-gamescope";   # exact launcher confirmed at impl time
        user = "jie";
      };
      default_session = {
        command = "${pkgs.greetd.greetd}/bin/agreety --cmd $SHELL";
        user = "greeter";
      };
    };
  };
  ```
  The `steam-gamescope` command string will be wired to whatever
  `programs.steam.gamescopeSession` actually installs (verified during
  implementation — either the `steam-gamescope` script on PATH or the explicit
  `gamescope --steam -- steam -gamepadui` invocation), rather than guessed.

### Host wiring — `hosts/nixos/nixmachine/default.nix`

- Add `../../../modules/nixos/gaming.nix` to `imports`.
- AMD 32-bit graphics is already enabled on the host — no change needed.
- `jie`'s account already exists (`wheel`, `audio`); confirm during
  implementation whether a `gamemode`/`input`/`video` group add is required
  (logind seat ACLs usually make this unnecessary — keep the diff minimal).

## Caveats (to document in the module + surface to the user)

- **Big Picture power menu:** Steam Big Picture's power controls include
  **Shutdown / Restart**, which power off the *entire machine* — killing the
  24/7 homelab services. To return to server mode, use Big Picture's plain
  **Exit** (quit Steam), not Shutdown.
- The monitor does not go truly dark on exit; it shows a text login prompt
  (then console-blanks on idle). This is the closest "headless" state with a
  physical display attached.

## Verification

- `nix fmt` (alejandra) — formatting.
- `nix flake check` — evaluation.
- `nixos-rebuild build --flake .#nixmachine` — builds without error.
- On the machine: boot → lands in Steam Big Picture; Exit → text console; SSH
  and homelab services reachable throughout. (Manual, on hardware.)

## Addendum (2026-07-05) — scope extension

After the initial console session landed, the scope was extended on branch
`feature/gaming-streaming`. This supersedes the "no remote streaming / no extra
tooling" non-goals above for the following, agreed items:

- **Steam polish** (`feat(gaming): proton-ge, mangohud, and 4k120 hdr gamescope
  session`): `extraCompatPackages = [proton-ge-bin]`, `extraPackages =
  [mangohud gamescope-wsi]`, and `gamescopeSession.args` tuned for the attached
  **4K / 120 Hz HDR** display (`-w 3840 -h 2160 -r 120 --xwayland-count 2 -e
  --hdr-enabled --mangoapp`). `capSysNice` retained.
- **Sunshine, model A** (`feat(gaming): sunshine stream host … via
  graphical-session wrapper`): `services.sunshine` with `openFirewall`,
  `capSysAdmin` (KMS capture), `autoStart`. Chosen over Steam's built-in Remote
  Play for real HDR / higher bitrate. It mirrors the physical gamescope → Steam
  session to Moonlight clients (Moonlight is a *client* — installed on other
  devices, not nixmachine; `moonlight-qt` deliberately NOT added to nixps).
  - **Session-target bridge:** greetd's `initial_session.command` now runs a
    `gamescope-session` wrapper (`pkgs.writeShellScript`) that
    `systemctl --user start graphical-session.target` (so the Sunshine user
    service, which is bound to that target, actually starts), runs
    `steam-gamescope`, and stops the target on exit (which also stops Sunshine —
    preserving the "exit → headless" behavior).
  - **Known risk (hardware-only):** gamescope *direct scanout* can defeat KMS
    capture (black frame). Mitigation = force composition on-hardware, or fall
    back to model B (Sunshine on a virtual display). The Nix build is unaffected.
  - **First use:** one-time PIN pairing at `https://<host>:47990`.
