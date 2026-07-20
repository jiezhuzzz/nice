_: {
  programs.ghostty.settings = {
    # The shared module sets font-size 16, which suits macOS Retina. niri
    # runs eDP-1 at scale 1.25 and ghostty sizes in logical points, so 16
    # there renders at an effective 20. 13 (16 / 1.25) matches the physical
    # size the Macs get.
    font-size = 13;

    # macOS-like Alt-as-Command keybindings (Linux)
    keybind = [
      "super+c=copy_to_clipboard"
      "super+v=paste_from_clipboard"
      "super+t=new_tab"
      "super+w=close_surface"
      "super+n=new_window"
      "super+q=quit"
    ];
  };
}
