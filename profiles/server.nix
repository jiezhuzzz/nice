# profiles/server.nix
# Shared home-manager profile for standalone HM on non-NixOS servers.
{config, ...}: {
  imports = [
    ../modules/home-manager/common/theme.nix
    ../modules/home-manager/common/bash.nix
    ../modules/home-manager/common/atuin.nix
    ../modules/home-manager/common/direnv.nix
    ../modules/home-manager/common/git.nix
    ../modules/home-manager/common/ssh.nix
    ../modules/home-manager/common/delta.nix
    ../modules/home-manager/common/gh.nix
    ../modules/home-manager/common/gitui.nix
    ../modules/home-manager/common/helix.nix
    ../modules/home-manager/common/yazi.nix
    ../modules/home-manager/common/zellij.nix
    ../modules/home-manager/common/eza.nix
    ../modules/home-manager/common/fzf.nix
    ../modules/home-manager/common/fd.nix
    ../modules/home-manager/common/ripgrep.nix
    ../modules/home-manager/common/bat.nix
    ../modules/home-manager/common/zoxide.nix
    ../modules/home-manager/common/bottom.nix
    ../modules/home-manager/common/fastfetch.nix
    ../modules/home-manager/common/claude-code.nix
    ../modules/home-manager/common/codex.nix
    ../modules/home-manager/common/uv.nix
    ../modules/home-manager/common/npm.nix
    ../modules/home-manager/common/oh-my-posh.nix
    ../modules/home-manager/common/tmux.nix
    ../modules/home-manager/common/rclone.nix
    ../modules/home-manager/linux/shpool.nix
    ../modules/home-manager/common/packages.nix
    ../modules/home-manager/common/aliases.nix
  ];

  home.preferXdgDirectories = true;
  xdg.enable = true;
  home.sessionVariables.CARGO_HOME = "${config.xdg.dataHome}/cargo";
  programs.man.generateCaches = false;
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";

  # Pin a forwarded SSH agent to a stable socket so tmux survives detach/
  # reconnect. With ForwardAgent each connection gets a fresh per-connection
  # $SSH_AUTH_SOCK that dies on disconnect; long-lived tmux panes capture the
  # original value and end up pointing at a dead socket. The login shell
  # repoints ~/.ssh/agent.sock at the live socket (.profile runs before .bashrc,
  # so it still sees the real socket), and every shell uses that stable path —
  # so even already-running panes transparently follow the refreshed link.
  # Kept in this profile (not a shared module): only standalone servers get a
  # forwarded agent.
  programs.bash = {
    profileExtra = ''
      if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock" ]; then
        ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
      fi
    '';
    bashrcExtra = ''
      [ -S "$HOME/.ssh/agent.sock" ] && export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    '';
  };
}
