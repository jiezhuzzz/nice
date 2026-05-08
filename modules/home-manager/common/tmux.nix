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
      # True color passthrough
      set -ga terminal-overrides ",*256col*:Tc,xterm-ghostty:Tc"

      # Focus events — lets helix detect pane switches
      set -g focus-events on

      # Pane index from 1 (matches window baseIndex)
      set -g pane-base-index 1

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Don't exit tmux when last session is destroyed
      set -g detach-on-destroy off

      # Only show session name if it's not a bare number (i.e. user-named)
      set -g status-left "#{?#{m:*[!0-9]*,#{session_name}},[#{session_name}] ,}"

      # Right status: catppuccin host module (icon + CPU/MEM/host text).
      set -g status-right-length 100
      set -g status-right "#{E:@catppuccin_status_host}"

      # Clipboard — vi copy mode yanks to system clipboard
      set -g set-clipboard on
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy"

      # Split panes with | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Navigate panes with vi keys
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Resize panes with vi keys
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # New window keeps current path
      bind c new-window -c "#{pane_current_path}"
    '';
  };

  catppuccin.tmux.extraConfig = ''
    # Rounded window indicators
    set -g @catppuccin_window_status_style "rounded"

    # Window text
    set -g @catppuccin_window_text " #{b:pane_current_path}:#{pane_current_command}"
    set -g @catppuccin_window_current_text " #{b:pane_current_path}:#{pane_current_command}"

    # Embed CPU/MEM into the host module text so the whole frame renders
    # via catppuccin's own host module (icon + accent + separators).
    set -g @catppuccin_host_text " #(${cpuScript})  #(${memScript}) #H"
  '';
}
