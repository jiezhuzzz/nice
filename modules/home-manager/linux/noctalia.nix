{pkgs, ...}: {
  # noctalia-shell: Quickshell-based desktop shell (status bar, notifications,
  # launcher, lock screen, control centre) for niri. Launched by niri via
  # spawn-at-startup in modules/home-manager/linux/niri.nix — upstream
  # deprecated the systemd user service in favour of that.
  #
  # Its settings live in ~/.config/noctalia and are deliberately NOT managed
  # here: noctalia writes them from its own settings GUI, so a read-only
  # store symlink would stop it saving.
  home.packages = [
    pkgs.noctalia-shell
    # Launches desktop entries as transient systemd user units; noctalia uses
    # it so spawned apps are not killed when the shell restarts.
    pkgs.app2unit
    # Qt6 platform theme. Without it Qt resolves no icon theme at all and
    # noctalia logs "Could not load icon ..." for every app entry.
    pkgs.qt6Packages.qt6ct
    pkgs.papirus-icon-theme
  ];

  home.sessionVariables = {
    # Quickshell is Qt6: prefer the Wayland platform plugin, fall back to xcb.
    QT_QPA_PLATFORM = "wayland;xcb";
    # Point Qt at qt6ct, which supplies the icon theme configured below.
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };

  # Minimal qt6ct config: this exists to give Qt an icon theme, nothing more.
  # Managed declaratively because we do not use the qt6ct GUI — if that
  # changes, this needs to become a writable file.
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    icon_theme=Papirus
    style=Fusion
  '';
}
