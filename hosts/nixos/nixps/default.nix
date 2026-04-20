{
  inputs,
  pkgs,
  ...
}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    ./hardware.nix
    ../../../modules/nixos/boot
    ../../../modules/nixos/hardware
    ../../../modules/nixos/desktop
    ../../../modules/nixos/secrets
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    wifitui
    git
    banana-cursor
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  networking.hostName = "nixps";

  time.timeZone = "America/Chicago";

  catppuccin.enable = true;
  catppuccin.flavor = user.theme.flavor;

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.fish;
  };

  networking.networkmanager.enable = true;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      ../../../modules/home-manager/common
      ../../../modules/home-manager/linux
    ];
    home.username = user.me.username;
    home.homeDirectory = "/home/${user.me.username}";
  };

  system.stateVersion = "26.05";
}
