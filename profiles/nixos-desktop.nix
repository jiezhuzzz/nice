# profiles/nixos-desktop.nix
# Shared NixOS profile for desktop/laptop machines.
{
  inputs,
  pkgs,
  user,
  ...
}: {
  imports = [
    ../modules/nixos/boot.nix
    ../modules/nixos/hardware
    ../modules/nixos/desktop
    ../modules/nixos/secrets.nix
  ];

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  catppuccin.enable = true;
  catppuccin.autoEnable = true;
  catppuccin.flavor = user.theme.flavor;

  networking.networkmanager.enable = true;

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.fish;
  };

  home-manager.users.${user.me.username} = {pkgs, ...}: {
    imports = [
      ./home/desktop.nix
      ../modules/home-manager/linux/packages.nix
      ../modules/home-manager/linux/niri.nix
      ../modules/home-manager/linux/ghostty.nix
      ../modules/home-manager/linux/shpool.nix
    ];

    home.pointerCursor = {
      name = "Banana";
      package = pkgs.banana-cursor;
      size = 32;
      gtk.enable = true;
    };
  };
}
