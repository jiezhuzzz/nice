{
  config,
  inputs,
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
  # noctalia v5: a Wayland shell (bar, notifications, launcher, control centre,
  # lock screen) for niri. Upstream ships its own home-manager module, so the
  # package and config file are wired through that rather than by hand.
  #
  # v5 is a ground-up rewrite: v4 was Quickshell/QML reading a JSON
  # settings.json, v5 is a native C++/meson binary reading TOML. No v4 settings
  # carry over, and the Qt plumbing v4 needed (qt6ct, QT_QPA_PLATFORM) went with
  # it — v5 links cairo/pango/librsvg, not Qt.
  #
  # Run as a systemd user service rather than niri's spawn-at-startup (the two
  # are mutually exclusive — both would start a second instance). The unit is
  # WantedBy the graphical-session target and carries X-Restart-Triggers on the
  # config file, so editing settings here restarts the shell on switch instead
  # of leaving a stale process serving its old view of the world.
  imports = [inputs.noctalia.homeModules.default];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    # Unlike v4, declaring settings here does NOT stop the in-app settings GUI
    # from saving. v5 layers its config: this is the declarative base at
    # ~/.config/noctalia/config.toml, while the GUI writes runtime overrides to
    # a separate settings.toml (and volatile state to state.toml). A read-only
    # store symlink for the base is therefore fine.
    #
    # Anything omitted keeps upstream's default; see example.toml in the
    # noctalia source for the full annotated set. The module runs
    # `noctalia config validate` at build time, so an invalid key fails the
    # build rather than silently degrading the shell at runtime.
    settings = {
      # eDP-1 is 1920x1200 and niri leaves it at scale 1, so the bar renders
      # small on a dense laptop panel. Scoped to the bar rather than the whole
      # shell via accessibility.ui_scale, which was tried and backed out.
      # Range is 0.5-4.0.
      #
      # Unrelated to the greeter's [output].scale, which only affects noctalia's
      # own greeter session — this machine logs in via greetd + tuigreet
      # (modules/nixos/desktop/login.nix), so that setting does not apply.
      bar.main = {
        scale = 1.5;
        smart_auto_hide = true;
        reserve_space = false;
      };

      shell = {
        # Required companion to systemd.enable above: without it, apps launched
        # from noctalia's launcher are children of the service and get killed
        # whenever the unit restarts. This is what v4 needed app2unit for; v5
        # does it natively.
        launch_apps_as_systemd_services = true;

        # Nothing else on this machine provides a polkit agent: polkitd runs,
        # but with no agent registered every GUI privilege prompt fails instead
        # of asking. That includes 1Password's system-auth, which
        # modules/nixos/desktop/1password.nix grants via polkitPolicyOwners.
        polkit_agent = true;

        # Pin the power menu to lock-aware actions. In particular, omit the
        # plain suspend action and route lock-and-suspend through the guarded
        # command below.
        session = {
          actions = [
            {
              action = "lock";
              shortcut = "1";
            }
            {
              action = "logout";
              shortcut = "2";
            }
            {
              action = "lock_and_suspend";
              shortcut = "3";
            }
            {
              action = "reboot";
              shortcut = "4";
            }
            {
              action = "shutdown";
              shortcut = "5";
              variant = "destructive";
            }
          ];
          power.suspend = "${secureSuspend}";
        };
      };

      # Noctalia owns the visual lock screen and idle flow. The user sleep
      # guard below covers suspend attempts that originate outside Noctalia.
      lockscreen.enabled = true;

      idle = {
        pre_action_fade_seconds = 2.0;
        behavior = {
          lock = {
            enabled = true;
            timeout = 300;
            action = "lock";
          };
          "screen-off" = {
            enabled = true;
            timeout = 330;
            action = "screen_off";
          };
          "lock-and-suspend" = {
            enabled = true;
            timeout = 600;
            action = "lock_and_suspend";
          };
        };
      };

      # Track the compositor-acknowledged lock state. The guard blocks sleep
      # while unlocked and is released only after session_locked fires.
      hooks = {
        started = startGuard;
        session_locked = stopGuard;
        session_unlocked = startGuard;
      };

      theme = {
        mode = "dark";
        source = "builtin";
        # Matches the catppuccin flavour applied globally across this flake.
        builtin = "Catppuccin";

        # Theme templates rewrite OTHER apps' config files to inject noctalia's
        # palette, which does not survive contact with home-manager: the ghostty
        # template runs `sed -i` on ~/.config/ghostty/config, replacing the
        # read-only store symlink with a regular file and failing the next
        # activation with "would be clobbered". The niri template likewise
        # appends an include line to config.kdl.
        #
        # Left empty so no app is themed this way. Both are already covered
        # better elsewhere: ghostty by the catppuccin flake, and niri's colours
        # are set explicitly in niri.nix (whose neutral focus-ring is a
        # deliberate choice the niri template would overwrite with mauve).
        #
        # NOTE: this is only the declarative base. noctalia's settings GUI
        # persists overrides to ~/.local/state/noctalia/settings.toml, which
        # wins over this file — enabling a template there will reintroduce the
        # breakage regardless of what is set here.
        templates.builtin_ids = [];
      };
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

  # Icon theme for the launcher and dock, which resolve application icons via
  # XDG icon lookup. Previously installed for qt6ct's benefit; kept because v5
  # still expects an icon theme to be present, even with the Qt bits gone.
  home.packages = [pkgs.papirus-icon-theme];
}
