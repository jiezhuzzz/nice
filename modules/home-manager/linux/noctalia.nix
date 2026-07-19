{pkgs, ...}: {
  # noctalia-shell: Quickshell-based desktop shell (status bar, notifications,
  # launcher, control centre) for niri. Launched by niri via spawn-at-startup
  # in modules/home-manager/linux/niri.nix — upstream deprecated the systemd
  # user service in favour of that.
  #
  # Its settings live in ~/.config/noctalia and are deliberately NOT managed
  # here: noctalia writes them from its own settings GUI, so a read-only
  # store symlink would stop it saving.
  home.packages = [
    pkgs.noctalia-shell
    # Launches desktop entries as transient systemd user units; noctalia uses
    # it so spawned apps are not killed when the shell restarts.
    pkgs.app2unit
  ];

  # Quickshell is Qt6: prefer the Wayland platform plugin, fall back to xcb.
  home.sessionVariables.QT_QPA_PLATFORM = "wayland;xcb";
}
