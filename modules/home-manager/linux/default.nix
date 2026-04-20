{pkgs, ...}: {
  # TODO: niri.nix is nixps-specific but currently imported by every Linux HM
  # consumer (including jie@server via hosts/foreign/jie@server). On the server
  # this declaratively writes ~/.config/niri/config.kdl (harmless — no daemon
  # reads it) and pulls niri-flake into eval. Move niri.nix to a nixps-only
  # path when this tree gains a second Linux HM host.
  imports = [
    ./packages.nix
    ./niri.nix
    ./ghostty.nix
    ./shpool.nix
  ];

  # Banana cursor — Wayland-only (no x11.enable; this laptop runs no Xorg apps).
  home.pointerCursor = {
    name = "Banana";
    package = pkgs.banana-cursor;
    size = 32;
    gtk.enable = true;
  };
}
