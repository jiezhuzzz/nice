{
  config,
  pkgs,
  ...
}: {
  # greetd + tuigreet: minimal Wayland-native login. GDM 50 (nixpkgs 26.11)
  # is broken for niri — `gdm-session-worker` strips PATH when spawning
  # `gdm-wayland-session`, which then can't find bare `niri-session`.
  #
  # Absolute path for niri-session dodges a similar PATH pitfall in greetd:
  # pam_env's `DEFAULT=` is a no-op when PATH is already inherited from
  # greetd.service, so we can't rely on /etc/pam/environment to add niri.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd ${config.programs.niri.package}/bin/niri-session";
      user = "greeter";
    };
  };
}
