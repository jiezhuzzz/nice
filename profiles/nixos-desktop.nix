# profiles/nixos-desktop.nix
# Shared NixOS profile for desktop/laptop machines.
{
  inputs,
  pkgs,
  ...
}: let
  user = import ../users/jie.nix;
in {
  imports = [
    ../modules/nixos/boot
    ../modules/nixos/hardware
    ../modules/nixos/desktop
    ../modules/nixos/secrets
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  catppuccin.enable = true;
  catppuccin.flavor = user.theme.flavor;

  networking.networkmanager.enable = true;

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.fish;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {pkgs, ...}: {
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
      ../modules/home-manager/common/delta.nix
      ../modules/home-manager/common/gh.nix
      ../modules/home-manager/common/ghostty
      # linux
      ../modules/home-manager/linux/packages.nix
      ../modules/home-manager/linux/niri.nix
      ../modules/home-manager/linux/ghostty.nix
      ../modules/home-manager/linux/shpool.nix
    ];
    home.username = user.me.username;
    home.homeDirectory = "/home/${user.me.username}";
    home.preferXdgDirectories = true;
    xdg.enable = true;
    programs.man.generateCaches = false;
    programs.home-manager.enable = true;
    home.stateVersion = "26.05";

    home.pointerCursor = {
      name = "Banana";
      package = pkgs.banana-cursor;
      size = 32;
      gtk.enable = true;
    };

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

    # Auto-load SSH keys into agent at login
    systemd.user.services.ssh-add-keys = {
      Unit.Description = "Load SSH keys into agent";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.openssh}/bin/ssh-add /run/agenix/github-ssh-key /run/agenix/git-signing-key /run/agenix/chameleon-ssh-key";
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
