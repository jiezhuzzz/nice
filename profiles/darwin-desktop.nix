# Shared darwin profile for all macOS desktop machines.
{
  inputs,
  pkgs,
  user,
  ...
}: {
  imports = [
    ../modules/nix-darwin/fonts.nix
    ../modules/nix-darwin/homebrew.nix
    ../modules/nix-darwin/secrets.nix
    ../modules/nix-darwin/system.nix
  ];

  # direnv 2.37.1 checkPhase hangs on macOS due to sandbox restrictions
  nixpkgs.overlays = [
    (final: prev: {
      direnv = prev.direnv.overrideAttrs (old: {
        doCheck = false;
      });
    })
  ];
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

  home-manager.users.${user.me.username} = {
    imports = [
      ./home/desktop.nix
      ../modules/home-manager/common/rclone.nix
      ../modules/home-manager/darwin/aerospace.nix
      ../modules/home-manager/darwin/karabiner.nix
      ../modules/home-manager/darwin/packages.nix
    ];
  };

  system.stateVersion = 6;
}
