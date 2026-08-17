_: {
  programs.zellij = {
    enable = true;
    settings = {
      show_startup_tips = false;
      show_release_notes = false;
      keybinds = {
        unbind = ["Ctrl b"];
      };
    };
  };
}
