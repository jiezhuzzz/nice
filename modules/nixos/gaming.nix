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
  #  1. Fix PATH. greetd starts sessions with a minimal PATH that lacks the
  #     NixOS system profile, so `steam-gamescope` (and the `gamescope` /
  #     `steam` / `mangoapp` it shells out to) were not found and the session
  #     died in ~1s. We prepend /run/current-system/sw/bin (and the standard
  #     /run/wrappers/bin). gamescope must resolve to the *plain* binary, not a
  #     capSysNice-wrapped one — see the programs.gamescope note below.
  #  2. Start Sunshine so it can capture the session, and stop it on exit —
  #     returning the box to the headless/agreety state. We start sunshine.service
  #     directly rather than graphical-session.target: the target has
  #     RefuseManualStart=yes so `systemctl start` of it silently fails, but
  #     sunshine `Wants=` it, so starting sunshine pulls the target in as a
  #     dependency (verified: both go active). Sunshine is the only consumer.
  #     (No `exec`, so the EXIT trap can fire.)
  #  3. Log the (verbose) session so a boot-time failure is debuggable over SSH.
  gamescope-session = pkgs.writeShellScript "gamescope-session" ''
    export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"
    ${pkgs.systemd}/bin/systemctl --user import-environment PATH
    ${pkgs.systemd}/bin/systemctl --user start sunshine.service
    trap '${pkgs.systemd}/bin/systemctl --user stop sunshine.service' EXIT
    steam-gamescope &> /tmp/gamescope-session.log
  '';

  # THE way to exit the gaming session: ends gamescope, returning greetd to the
  # text console. Runnable as jie from SSH or any console — no sudo, since
  # gamescope is jie's own process. Steam's Big Picture "Switch to Desktop" does
  # NOT work here — it triggers a Steam self-shutdown that hangs in the gamescope
  # session — so this is the intended exit. SIGTERM first, then SIGKILL.
  game-stop = pkgs.writeShellScriptBin "game-stop" ''
    export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

    # 1. Graceful: ask Steam to quit. It closes any running game first (so the
    #    game gets to save), then exits, and gamescope follows since Steam is
    #    its child. Nothing to kill in the common case.
    steam -shutdown &> /dev/null || true
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      ${pkgs.procps}/bin/pgrep -x gamescope-wl > /dev/null || break
      ${pkgs.coreutils}/bin/sleep 1
    done

    # 2. Steam ignored us (or was wedged): ask gamescope itself to go.
    ${pkgs.procps}/bin/pkill -TERM -f 'gamescope --steam'
    ${pkgs.coreutils}/bin/sleep 3

    # 3. Last resort. A SIGKILLed gamescope cannot reap its own children: the
    #    gamescopereaper holding the game gets reparented to init and the game
    #    (proton/wine) keeps running with no window — audible background music
    #    long after the session "ended". Kill the reapers explicitly, or every
    #    forced stop leaks a headless game.
    ${pkgs.procps}/bin/pkill -KILL -f 'gamescope --steam'
    ${pkgs.procps}/bin/pkill -KILL -x gamescopereaper
    exit 0
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
      # Deliberately NO --cursor-scale-height: it linearly upscales whatever
      # bitmap the client supplies, so a 24px cursor blown up 3× is just blurry.
      # A natively-large cursor theme (XCURSOR_SIZE below) is sharp instead.
    ];
  };

  # gamescope is auto-enabled by gamescopeSession, so this only needs `enable`.
  # We deliberately do NOT set capSysNice: the NixOS security wrapper grants
  # gamescope *inheritable* CAP_SYS_NICE (getcap shows `cap_sys_nice=eip`), and
  # that inheritable cap leaks into Steam's bubblewrap sandbox, which aborts with
  # "bwrap: Unexpected capabilities but not setuid" → Steam never launches and
  # the session dies in ~1s, falling back to the greeter. Losing gamescope's
  # realtime scheduling priority is a minor frame-pacing cost; a Steam that
  # actually starts is the point.
  programs.gamescope.enable = true;

  # The gamescope session's `--mangoapp` flag launches the `mangoapp` binary
  # (from mangohud) directly from gamescope — which lives OUTSIDE Steam's FHS, so
  # the mangohud in programs.steam.extraPackages isn't visible to it. Put it on
  # the system PATH so gamescope can find it (else: endless "Failed to start
  # process mangoapp" errors).
  environment.systemPackages = [
    pkgs.mangohud
    pkgs.banana-cursor # cursor theme, see XCURSOR_* below
    game-stop # end the gaming session from SSH/console (the intended exit)
  ];

  # Cursor. This host had no cursor theme at all, so libXcursor fell back to a
  # 24px default — invisible on a 2160p panel, and unfixable by scaling (see the
  # --cursor-scale-height note above).
  #
  # Banana is the same theme nixps uses (profiles/nixos-desktop.nix), and it
  # ships native bitmaps at 16/20/22/24/28/32/40/48/56/64/72/80/88/96, so 96
  # is drawn 1:1 with no resampling. nixps sets 40 for a 1440p desktop; a 4K
  # ten-foot UI wants roughly this much more.
  #
  # sessionVariables (not the wrapper) because these must apply however the
  # session starts — greetd autologin or a bare `steam-gamescope` from a console
  # login. Both go through PAM, which is what sets these.
  environment.sessionVariables = {
    XCURSOR_THEME = "Banana";
    XCURSOR_SIZE = "96";
  };

  # MangoHud defaults to a 24px font, which is unreadable on a 2160p panel at
  # couch distance. It resolves config in this order: $MANGOHUD_CONFIGFILE →
  # ~/.config/MangoHud/{<app>,MangoHud}.conf → /etc/MangoHud.conf. Using the
  # /etc fallback keeps this working no matter how the session is launched
  # (greetd wrapper or a bare `steam-gamescope` from the console), and leaves
  # the per-user paths free to override it.
  # font_scale is a plain multiplier over every element, so the overlay box
  # grows with the text. Bump it if 2.5× still reads small.
  environment.etc."MangoHud.conf".text = ''
    font_scale=5
  '';

  # Performance CPU governor while a game is running.
  programs.gamemode.enable = true;

  # Re-downloadable game libraries live on fast/games (see disko.nix). The
  # dataset mounts as root:games with setgid (2775), so every child inherits the
  # shared group. jie is a member (takes effect on next login).
  #
  # ⚠️  Registering /fast/games as a Steam library is NOT declarable here: the
  #     library list is Steam client state in
  #     ~/.local/share/Steam/{config,steamapps}/libraryfolders.vdf, and Steam
  #     only auto-detects removable/SD media — never an internal mountpoint. It
  #     has been added by hand; if it ever goes missing, re-add it with Steam
  #     STOPPED (Steam rewrites the file on exit, clobbering live edits):
  #       game-stop  →  add an entry with "path" "/fast/games" to BOTH vdfs
  #                  →  mkdir -p /fast/games/steamapps
  #                  →  sudo systemctl restart greetd
  #     Big Picture's Storage page has no folder browser (desktop-mode only),
  #     so the vdf edit is the only route on this box.
  users.groups.games = {};
  users.users.${user.me.username}.extraGroups = ["games"];

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
