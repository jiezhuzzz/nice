{...}: {
  imports = [
    ./packages.nix
    ./theme.nix
    ./helix.nix
    ./yazi.nix
    ./fish.nix
    ./atuin.nix
    ./direnv.nix
    ./git.nix
    ./ssh.nix
    ./eza.nix
    ./fzf.nix
    ./zellij.nix
    ./zoxide.nix
    ./zed.nix
    ./rime.nix
    ./fd.nix
    ./fastfetch.nix
    ./bat.nix
    ./gitui.nix
    ./bottom.nix
    ./ripgrep.nix
    ./agent.nix
    ./delta.nix
    ./gh.nix
    ./ghostty.nix
  ];

  home.preferXdgDirectories = true;
  xdg.enable = true;

  programs.man.generateCaches = false;
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
}
