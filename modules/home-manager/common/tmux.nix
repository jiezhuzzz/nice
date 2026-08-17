{pkgs, ...}: let
  # tmux-mem-cpu-load with -m 2 (mem %), -g 0 (no graph), -a 0 (no load)
  # outputs just one number per field.
  tmcl = "${pkgs.tmux-mem-cpu-load}/bin/tmux-mem-cpu-load -g 0 -m 2 -a 0 -i 2";
  memScript = pkgs.writeShellScript "tmux-mem" ''
    set -- $(${tmcl})
    printf '%s' "$1"
  '';
  cpuScript = pkgs.writeShellScript "tmux-cpu" ''
    set -- $(${tmcl})
    printf '%s' "$2"
  '';
in {
  programs.tmux = {
    enable = true;
    mouse = true;
    terminal = "tmux-256color";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 10000;
    keyMode = "vi";
    extraConfig = ''
      set -ga terminal-overrides ",*256col*:Tc,xterm-ghostty:Tc"

      # Lets helix detect pane switches.
      set -g focus-events on

      # Extended (modified) key reporting. By default tmux flattens chords like
      # shift+enter and ctrl+enter down to a bare \r, so a TUI inside tmux can't
      # tell them apart from plain Enter. `on` makes tmux forward the real chord
      # once the application asks for it (pi does so automatically when the
      # Kitty keyboard protocol isn't available), and `csi-u` picks the modern
      # CSI-u encoding — shift+enter as \x1b[13;2u — over tmux's default xterm
      # modifyOtherKeys form (\x1b[27;2;13~). Recommended by pi's docs
      # (libexec/pi/docs/tmux.md); needs tmux >= 3.5 for extended-keys-format
      # (nixpkgs ships 3.7b). Takes effect only on a fresh server:
      # `tmux kill-server`.
      set -g extended-keys on
      set -g extended-keys-format csi-u

      set -g pane-base-index 1
      set -g renumber-windows on
      set -g detach-on-destroy off

      # Only show session name if it's not a bare number (i.e. user-named)
      set -g status-left "#{?#{m:*[!0-9]*,#{session_name}},[#{session_name}] ,}"

      set -g status-right-length 100
      set -g status-right "#{E:@catppuccin_status_host}"

      set -g set-clipboard on
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy"

      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      bind c new-window -c "#{pane_current_path}"
    '';
  };

  catppuccin.tmux.extraConfig = ''
    set -g @catppuccin_window_status_style "rounded"

    set -g @catppuccin_window_text " #{b:pane_current_path}:#{pane_current_command}"
    set -g @catppuccin_window_current_text " #{b:pane_current_path}:#{pane_current_command}"

    # Embed CPU/MEM into the host module text so the whole frame renders
    # via catppuccin's own host module (icon + accent + separators).
    set -g @catppuccin_host_text "  #(${cpuScript})   #(${memScript})  #H"
  '';
}
