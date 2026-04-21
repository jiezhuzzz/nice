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
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      ../modules/home-manager/common
      ../modules/home-manager/linux
    ];
    home.username = user.me.username;
    home.homeDirectory = "/home/${user.me.username}";
  };
}
