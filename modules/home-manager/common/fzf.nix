_: {
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

    # Atuin owns Ctrl-R for history search — its bash integration is sourced after
    # fzf's and wins at runtime. Disable fzf's bash Ctrl-R widget so both don't
    # claim the same key, which silences home-manager's conflict warning. fzf keeps
    # Ctrl-T (files) and Alt-C (cd). Scoped to bash; fish handles keybindings
    # separately and doesn't conflict.
    historyWidget.bash.command = "";
  };
}
