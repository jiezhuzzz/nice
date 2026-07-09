_: {
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

    # Atuin owns Ctrl-R for history search — its shell integration is sourced after
    # fzf's and wins at runtime. Disable fzf's Ctrl-R widget in both bash and fish so
    # both don't claim the same key, which silences home-manager's conflict warning.
    # fzf keeps Ctrl-T (files) and Alt-C (cd).
    historyWidget.bash.command = "";
    historyWidget.fish.command = "";
  };
}
