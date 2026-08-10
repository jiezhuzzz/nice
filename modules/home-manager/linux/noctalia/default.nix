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
{inputs, ...}: {
  imports = [
    inputs.noctalia.homeModules.default
    ./shell.nix
    ./sleep-guard.nix
  ];
}
