# profiles/darwin-desktop.nix
# Shared darwin profile for all macOS desktop machines.
{
  inputs,
  pkgs,
  ...
}: let
  user = import ../users/jie.nix;
in {
  imports = [
    ../modules/nix-darwin/fonts
    ../modules/nix-darwin/homebrew
    ../modules/nix-darwin/secrets
    ../modules/nix-darwin/system
  ];

  nixpkgs.config.allowUnfree = true;
  nix.enable = false;

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = user.me.username;

  users.knownUsers = [user.me.username];
  users.users.${user.me.username} = {
    uid = 501;
    home = "/Users/${user.me.username}";
    shell = pkgs.fish;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      # common
      ../modules/home-manager/common/packages.nix
      ../modules/home-manager/common/theme.nix
      ../modules/home-manager/common/helix.nix
      ../modules/home-manager/common/yazi.nix
      ../modules/home-manager/common/fish.nix
      ../modules/home-manager/common/atuin.nix
      ../modules/home-manager/common/direnv.nix
      ../modules/home-manager/common/git.nix
      ../modules/home-manager/common/ssh.nix
      ../modules/home-manager/common/eza.nix
      ../modules/home-manager/common/fzf.nix
      ../modules/home-manager/common/zellij.nix
      ../modules/home-manager/common/zoxide.nix
      ../modules/home-manager/common/zed.nix
      ../modules/home-manager/common/rime.nix
      ../modules/home-manager/common/fd.nix
      ../modules/home-manager/common/fastfetch.nix
      ../modules/home-manager/common/bat.nix
      ../modules/home-manager/common/bun.nix
      ../modules/home-manager/common/gitui.nix
      ../modules/home-manager/common/bottom.nix
      ../modules/home-manager/common/ripgrep.nix
      ../modules/home-manager/common/claude-code.nix
      ../modules/home-manager/common/codex.nix
      ../modules/home-manager/common/uv.nix
      ../modules/home-manager/common/npm.nix
      ../modules/home-manager/common/delta.nix
      ../modules/home-manager/common/gh.nix
      ../modules/home-manager/common/ghostty
      # darwin
      ../modules/home-manager/darwin/aerospace.nix
      ../modules/home-manager/darwin/karabiner.nix
      ../modules/home-manager/darwin/packages.nix
    ];
    home.username = user.me.username;
    home.homeDirectory = "/Users/${user.me.username}";
    home.preferXdgDirectories = true;
    xdg.enable = true;
    programs.man.generateCaches = false;
    programs.home-manager.enable = true;
    home.stateVersion = "26.05";

    # SSH identity pinning (keys decrypted by agenix to /run/agenix/)
    programs.ssh.matchBlocks."github.com" = {
      identityFile = "/run/agenix/github-ssh-key";
      identitiesOnly = true;
    };
    programs.ssh.matchBlocks."tacc" = {
      identityFile = "/run/agenix/chameleon-ssh-key";
      identitiesOnly = true;
    };
    programs.ssh.matchBlocks."10.52.*.*" = {
      identityFile = "/run/agenix/chameleon-ssh-key";
      identitiesOnly = true;
    };

    # Auto-load SSH keys into macOS system agent at login
    launchd.agents.ssh-add-keys = {
      enable = true;
      config = {
        Label = "com.user.ssh-add-keys";
        ProgramArguments = [
          "/usr/bin/ssh-add"
          "/run/agenix/github-ssh-key"
          "/run/agenix/git-signing-key"
          "/run/agenix/chameleon-ssh-key"
        ];
        RunAtLoad = true;
      };
    };
  };

  system.stateVersion = 6;
}
