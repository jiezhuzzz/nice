{...}: {
  services.displayManager.gdm.enable = true;
  # GNOME desktop disabled — niri is the window manager on this host.
  # services.desktopManager.gnome.enable = true;

  # Fractional scaling in GNOME Wayland + cursor + lid actions
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer']

    [org.gnome.settings-daemon.plugins.power]
    lid-close-ac-action='nothing'
    lid-close-battery-action='nothing'
    # Don't suspend when idle — s2idle crashes on Panther Lake (kernel 6.19).
    # Lock the screen instead (blank + lock via screensaver).
    sleep-inactive-ac-type='nothing'
    sleep-inactive-battery-type='nothing'

    [org.gnome.desktop.screensaver]
    lock-enabled=true
    lock-delay=uint32 0

    [org.gnome.desktop.session]
    idle-delay=uint32 300

    [org.gnome.desktop.interface]
    cursor-theme='Banana'
  '';
}
