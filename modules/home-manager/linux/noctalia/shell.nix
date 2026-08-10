# The shell itself: bar, launcher, lock screen, idle flow, theme.
{pkgs, ...}: {
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
      # Unrelated to the login greeter's scale: this machine logs in via
      # noctalia-greeter (modules/nixos/desktop/login.nix), which reads its own
      # [output].scale from /var/lib/noctalia-greeter/greeter.toml, not this key.
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
        # command in sleep-guard.nix (which sets power.suspend on this same
        # shell.session tree).
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
        };
      };

      # Noctalia owns the visual lock screen and idle flow. The sleep guard in
      # sleep-guard.nix covers suspend attempts that originate outside Noctalia.
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
        # are set explicitly in niri/config.kdl (whose neutral focus-ring is a
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

  # Icon theme for the launcher and dock, which resolve application icons via
  # XDG icon lookup. Previously installed for qt6ct's benefit; kept because v5
  # still expects an icon theme to be present, even with the Qt bits gone.
  home.packages = [pkgs.papirus-icon-theme];
}
