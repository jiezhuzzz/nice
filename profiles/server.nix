# profiles/server.nix
# Shared home-manager profile for standalone HM on non-NixOS servers.
{...}: {
  imports = [
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
    ../modules/home-manager/linux/shpool.nix
  ];

  home.preferXdgDirectories = true;
  xdg.enable = true;
  programs.man.generateCaches = false;
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
}
