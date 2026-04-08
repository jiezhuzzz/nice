{
  inputs,
  pkgs,
  ...
}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    ../../../modules/nix-darwin/homebrew
    ../../../modules/nix-darwin/system
  ];

  nixpkgs.config.allowUnfree = true;
  nix.enable = false;

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  networking.hostName = "nacbook";
  networking.computerName = "nacbook";

  nixpkgs.hostPlatform = "aarch64-darwin";

  time.timeZone = "America/Chicago";

  system.primaryUser = user.me.username;

  users.users.${user.me.username} = {
    home = "/Users/${user.me.username}";
    shell = pkgs.fish;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      ../../../modules/home-manager/common
    ];
    home.username = user.me.username;
    home.homeDirectory = "/Users/${user.me.username}";
  };

  system.stateVersion = 6;
}
