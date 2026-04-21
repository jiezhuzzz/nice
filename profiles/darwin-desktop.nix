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
      ../modules/home-manager/common
      ../modules/home-manager/darwin/aerospace.nix
      ../modules/home-manager/darwin/karabiner.nix
      ../modules/home-manager/darwin/packages.nix
    ];
    home.username = user.me.username;
    home.homeDirectory = "/Users/${user.me.username}";
  };

  system.stateVersion = 6;
}
