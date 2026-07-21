_: {
  # PDF viewer, kept for the zed-latex extension's preview feature.
  #
  # Nothing configures the preview on the Zed side: zed-latex auto-detects a
  # supported viewer on $PATH and writes texlab's forwardSearch settings
  # itself. zathura is one of only four viewers it also wires inverse search
  # for (alongside sioyek, evince and okular), and the other three either pull
  # in GNOME/KDE or are less documented — so this is the cheapest viewer that
  # gets both search directions with no Zed settings at all.
  # https://github.com/rzukic/zed-latex/wiki/Preview
  #
  # Linux-only on purpose: modules/home-manager/common/zed.nix is shared with
  # the Macs, where the extension auto-detects Skim instead.
  #
  # Declared via programs.zathura rather than home.packages so the catppuccin
  # flake themes it — catppuccin.zathura.enable is already true globally, but
  # it hooks this module and does nothing for a bare package.
  programs.zathura.enable = true;
}
