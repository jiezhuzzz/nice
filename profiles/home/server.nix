# Home config for headless machines: standalone HM on foreign servers
# (chameleon/goku/vegeta) and, via profiles/homelab.nix, NixOS homelab boxes.
{
  imports = [
    ./core.nix
    ../../modules/home-manager/common/bash.nix
    ../../modules/home-manager/common/oh-my-posh.nix
    ../../modules/home-manager/common/tmux.nix
    ../../modules/home-manager/common/rclone.nix
    ../../modules/home-manager/linux/shpool.nix
  ];

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
