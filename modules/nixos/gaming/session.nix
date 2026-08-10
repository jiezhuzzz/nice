# The session lifecycle: greetd boots straight into gamescope → Steam, and
# game-stop is THE way back out.
{
  pkgs,
  user,
  ...
}: let
  # Session wrapper launched by greetd. Responsibilities:
  #  1. Fix PATH. greetd starts sessions with a minimal PATH that lacks the
  #     NixOS system profile, so `steam-gamescope` (and the `gamescope` /
  #     `steam` / `mangoapp` it shells out to) were not found and the session
  #     died in ~1s. We prepend /run/current-system/sw/bin (and the standard
  #     /run/wrappers/bin). gamescope must resolve to the *plain* binary, not a
  #     capSysNice-wrapped one — see the programs.gamescope note in steam.nix.
  #  2. Start Sunshine (services.sunshine, sunshine.nix) so it can capture the
  #     session, and stop it on exit — returning the box to the
  #     headless/agreety state. We start sunshine.service directly rather than
  #     graphical-session.target: the target has RefuseManualStart=yes so
  #     `systemctl start` of it silently fails, but sunshine `Wants=` it, so
  #     starting sunshine pulls the target in as a dependency (verified: both
  #     go active). Sunshine is the only consumer.
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
  environment.systemPackages = [
    game-stop # end the gaming session from SSH/console (the intended exit)
  ];

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
}
