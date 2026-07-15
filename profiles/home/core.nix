# profiles/home/core.nix
# CLI toolkit + home settings shared by every machine (desktop and server).
{config, ...}: {
  imports = [
    ../../modules/home-manager/common/packages.nix
    ../../modules/home-manager/common/aliases.nix
    ../../modules/home-manager/common/theme.nix
    ../../modules/home-manager/common/helix.nix
    ../../modules/home-manager/common/yazi.nix
    ../../modules/home-manager/common/atuin.nix
    ../../modules/home-manager/common/direnv.nix
    ../../modules/home-manager/common/git.nix
    ../../modules/home-manager/common/ssh.nix
    ../../modules/home-manager/common/eza.nix
    ../../modules/home-manager/common/fzf.nix
    ../../modules/home-manager/common/zellij.nix
    ../../modules/home-manager/common/zoxide.nix
    ../../modules/home-manager/common/fd.nix
    ../../modules/home-manager/common/fastfetch.nix
    ../../modules/home-manager/common/bat.nix
    ../../modules/home-manager/common/bun.nix
    ../../modules/home-manager/common/gitui.nix
    ../../modules/home-manager/common/bottom.nix
    ../../modules/home-manager/common/ripgrep.nix
    ../../modules/home-manager/common/claude-code.nix
    ../../modules/home-manager/common/codex.nix
    ../../modules/home-manager/common/uv.nix
    ../../modules/home-manager/common/npm.nix
    ../../modules/home-manager/common/delta.nix
    ../../modules/home-manager/common/gh.nix
  ];

  home.preferXdgDirectories = true;
  xdg.enable = true;
  home.sessionVariables.CARGO_HOME = "${config.xdg.dataHome}/cargo";
  # Generic user-bin dir (npm --prefix, pipx, ad-hoc scripts) ahead of the profile.
  home.sessionPath = ["${config.home.homeDirectory}/.local/bin"];
  programs.man.generateCaches = false;
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
}
