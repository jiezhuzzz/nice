{pkgs, ...}: let
  # tmux-mem-cpu-load with -m 2 (mem %), -g 0 (no graph), -a 0 (no load)
  # outputs just one number; framing is built in the status-right format
  # so each indicator inherits the catppuccin module frame (separators,
  # icon block bg, text block bg) used by status_host.
  tmcl = "${pkgs.tmux-mem-cpu-load}/bin/tmux-mem-cpu-load -g 0 -m 2 -a 0 -i 2";
  memScript = pkgs.writeShellScript "tmux-mem" ''
    set -- $(${tmcl})
    printf '%s' "$1"
  '';
  cpuScript = pkgs.writeShellScript "tmux-cpu" ''
    set -- $(${tmcl})
    printf '%s' "$2"
  '';
  # Disk usage % of the partition $HOME lives on (root on Linux, Data
  # volume on macOS) — single number, no trailing %.
  diskScript = pkgs.writeShellScript "tmux-disk" ''
    df -P "$HOME" | ${pkgs.gawk}/bin/awk 'NR==2 {gsub("%",""); print $5}'
  '';
  # Replicate catppuccin's status module shape: left separator, icon on
  # accent-colored bg, text on surface_0 bg, right separator.
  framed = color: icon: content: ''#[fg=${color},bg=default]#{@catppuccin_status_left_separator}#[fg=#{@thm_bg},bg=${color}]${icon} #[fg=#{@thm_fg},bg=#{@thm_surface_0}] ${content} #[fg=#{@thm_surface_0},bg=default]#{@catppuccin_status_right_separator}'';
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

      # Right status: catppuccin host module only (no default date/time)
      set -g status-right-length 100
      set -g status-right "${framed "#{@thm_red}" "" "#(${cpuScript})"} ${framed "#{@thm_yellow}" "" "#(${memScript})"} ${framed "#{@thm_green}" "󱛟" "#(${diskScript})"} #{E:@catppuccin_status_host}"

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

    # Right status: hostname only, no date/time
    set -g @catppuccin_status_modules_right "host"
  '';
}
