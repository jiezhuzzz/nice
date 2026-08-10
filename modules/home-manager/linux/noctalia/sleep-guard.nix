# Block system sleep until Noctalia has actually locked the session: a
# systemd-inhibit guard unit, a suspend wrapper that waits for the lock
# acknowledgement, and the noctalia hooks that arm/release the guard. The keys
# set under programs.noctalia.settings here (hooks.*, shell.session.power.suspend)
# are disjoint from the leaves shell.nix sets, so the two files merge cleanly
# into one settings tree.
{
  config,
  pkgs,
  ...
}: let
  sleepGuardUnit = "noctalia-sleep-guard.service";
  lockMarker = "$XDG_RUNTIME_DIR/noctalia-session-locked";
  systemctl = "${pkgs.systemd}/bin/systemctl";

  secureSuspend = pkgs.writeShellScript "noctalia-secure-suspend" ''
    set -euo pipefail

    lock_marker="$XDG_RUNTIME_DIR/noctalia-session-locked"
    for _ in {1..20}; do
      if [[ -e "$lock_marker" ]]; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 0.1
    done

    if [[ ! -e "$lock_marker" ]]; then
      echo "refusing to suspend without an acknowledged Noctalia lock" >&2
      exit 1
    fi

    ${systemctl} --user stop ${sleepGuardUnit}
    exec ${systemctl} suspend
  '';

  startGuard =
    "${pkgs.coreutils}/bin/rm -f \"${lockMarker}\""
    + " && ${systemctl} --user start ${sleepGuardUnit}";
  stopGuard =
    "${pkgs.coreutils}/bin/touch \"${lockMarker}\""
    + " && ${systemctl} --user stop ${sleepGuardUnit}";
in {
  programs.noctalia.settings = {
    shell.session.power.suspend = "${secureSuspend}";

    # Track the compositor-acknowledged lock state. The guard blocks sleep
    # while unlocked and is released only after session_locked fires.
    hooks = {
      started = startGuard;
      session_locked = stopGuard;
      session_unlocked = startGuard;
    };
  };

  systemd.user.services.noctalia-sleep-guard = {
    Unit = {
      Description = "Block sleep until Noctalia has locked the session";
      PartOf = [config.wayland.systemd.target];
      Before = ["noctalia.service"];
    };

    Service = {
      Type = "simple";
      ExecStart =
        "${pkgs.systemd}/bin/systemd-inhibit"
        + " --what=sleep"
        + " --who=Noctalia"
        + " --why=\"Session is not locked\""
        + " --mode=block"
        + " ${pkgs.coreutils}/bin/sleep infinity";
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install.WantedBy = [config.wayland.systemd.target];
  };
}
