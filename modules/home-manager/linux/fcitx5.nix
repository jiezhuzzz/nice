{...}: {
  # Fcitx5's Classic UI draws Rime's candidate window. Pin both its font and
  # theme: the defaults use Sans 10 and the plain built-in theme, which are
  # too small and visually inconsistent on the laptop's scale-1 display.
  home.file.".config/fcitx5/conf/classicui.conf".text = ''
    Vertical Candidate List=False
    WheelForPaging=True
    Font="Noto Sans CJK SC 16"
    MenuFont="Noto Sans CJK SC 14"
    UseInputMethodLanguageToDisplayText=True
    Theme=catppuccin-frappe-mauve
    DarkTheme=catppuccin-frappe-mauve
    UseDarkTheme=False
    UseAccentColor=False
    PerScreenDPI=False
    ForceWaylandDPI=0
    EnableFractionalScale=True
  '';
}
