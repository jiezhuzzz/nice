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

  # Session wrapper launched by greetd. Responsibilities:
  #  1. Fix PATH. greetd starts sessions with a minimal PATH that lacks both the
  #     NixOS system profile and the setuid-wrapper dir, so `steam-gamescope`
  #     (and the `gamescope` / `steam` / `mangoapp` it shells out to) were not
  #     found and the session died in ~1s. `/run/wrappers/bin` must come first so
  #     the capSysNice-wrapped `gamescope` wins over the plain one.
  #  2. Bring up jie's `graphical-session.target` so services bound to it
  #     (Sunshine) start, and tear it back down when Steam exits — which stops
  #     Sunshine and returns the box to the headless/agreety state. (No `exec`,
  #     so the EXIT trap can fire.)
  #  3. Log the (verbose) session so a boot-time failure is debuggable over SSH.
  gamescope-session = pkgs.writeShellScript "gamescope-session" ''
    export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"
    ${pkgs.systemd}/bin/systemctl --user import-environment PATH
    ${pkgs.systemd}/bin/systemctl --user start graphical-session.target
    trap '${pkgs.systemd}/bin/systemctl --user stop graphical-session.target' EXIT
    steam-gamescope &> /tmp/gamescope-session.log
  '';
in {
  # Steam + the gamescope "steam" session. programs.steam.enable already turns
  # on hardware.steam-hardware (controller udev rules) and 32-bit audio, and
  # installs the `steam-gamescope` launcher onto the system PATH. Unfree is
  # already allowed by the homelab profile; 32-bit graphics is enabled on the
  # host.
  programs.steam = {
    enable = true;

    # GE-Proton as a selectable per-game compatibility tool — broader game
    # coverage than stock Proton.
    extraCompatPackages = [pkgs.proton-ge-bin];

    # Injected into Steam's FHS runtime: the MangoHud overlay and the gamescope
    # Vulkan WSI layer (the latter is what makes HDR / tearing control work under
    # gamescope).
    extraPackages = with pkgs; [
      mangohud
      gamescope-wsi
    ];

    gamescopeSession.enable = true;
    # gamescope session tuned for the attached 4K/120 Hz HDR display:
    #   -w / -h / -r → 3840×2160 @ 120 Hz   --hdr-enabled → HDR output (relies on
    #   the gamescope-wsi layer above)      --mangoapp    → MangoHud overlay
    #   --xwayland-count 2 and -e are the standard Steam-Deck-style session flags.
    # These are validated at runtime by gamescope on the actual hardware.
    gamescopeSession.args = [
      "-w 3840"
      "-h 2160"
      "-r 120"
      "--xwayland-count 2"
      "-e"
      "--hdr-enabled"
      "--mangoapp"
    ];
  };

  # gamescope compositor. Enabling gamescopeSession already defaults
  # programs.gamescope.enable to true; we keep this block for capSysNice, which
  # lets gamescope request realtime priority for smoother frame pacing.
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # The gamescope session's `--mangoapp` flag launches the `mangoapp` binary
  # (from mangohud) directly from gamescope — which lives OUTSIDE Steam's FHS, so
  # the mangohud in programs.steam.extraPackages isn't visible to it. Put it on
  # the system PATH so gamescope can find it (else: endless "Failed to start
  # process mangoapp" errors).
  environment.systemPackages = [pkgs.mangohud];

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
        command = "${gamescope-session}"; # wrapper: starts graphical-session.target (for Sunshine), then steam-gamescope
        user = user.me.username;
      };
      default_session = {
        # A concrete shell, NOT `$SHELL` — that resolved to the `greeter` system
        # user's shell (nologin), so authenticating as jie ran nologin →
        # "account currently unavailable". agreety runs --cmd as the user who
        # just authenticated, so this gives jie a real login shell.
        command = "${pkgs.greetd}/bin/agreety --cmd ${pkgs.bashInteractive}/bin/bash";
        # user defaults to "greeter"
      };
    };
  };

  # Sunshine — self-hosted game-stream host; Moonlight clients on your other
  # devices connect to it. Model A: it KMS-captures the physical gamescope →
  # Steam session and mirrors it. Runs as jie's user service bound to
  # graphical-session.target (brought up by the gamescope-session wrapper above),
  # so it is live during the session and stops when you exit Steam.
  #   openFirewall → Moonlight discovery + stream ports
  #   capSysAdmin  → CAP_SYS_ADMIN, required for KMS/DRM capture of the output
  #   uinput (Moonlight virtual controllers) + Avahi discovery are auto-enabled.
  # First connection needs a one-time PIN pairing at https://<host>:47990.
  # ⚠️  gamescope direct scanout can defeat KMS capture (black frame). If that
  #     happens it needs an on-hardware tweak (force composition) — the Nix build
  #     is unaffected either way.
  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
    autoStart = true;
  };
}
