{pkgs, ...}: {
  programs.fastfetch = {
    enable = true;
    # The zpool module dlopens libzfs at runtime; the nixpkgs wrapper only
    # puts it on LD_LIBRARY_PATH with zfsSupport enabled.
    package = pkgs.fastfetch.override {
      zfsSupport = pkgs.stdenv.hostPlatform.isLinux;
    };
    settings = {
      # Default module list with zpool added: on ZFS, per-mountpoint disk
      # stats only cover a single dataset, so pool usage is invisible.
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "display"
        "de"
        "wm"
        "wmtheme"
        "theme"
        "icons"
        "font"
        "cursor"
        "terminal"
        "terminalfont"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "zpool"
        "localip"
        "battery"
        "poweradapter"
        "locale"
        "break"
        "colors"
      ];
    };
  };
}
