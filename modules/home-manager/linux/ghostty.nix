_: {
  programs.ghostty.settings = {
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
