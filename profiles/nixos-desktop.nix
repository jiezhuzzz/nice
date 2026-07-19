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
    ../modules/nixos/tailscale.nix
  ];

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    jq
    wget
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

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
      ../modules/home-manager/linux/noctalia.nix
      ../modules/home-manager/linux/chromium.nix
      ../modules/home-manager/linux/ghostty.nix
      ../modules/home-manager/linux/shpool.nix
      ../modules/home-manager/linux/swaylock.nix
    ];

    home.pointerCursor = {
      name = "Banana";
      package = pkgs.banana-cursor;
      size = 64;
      gtk.enable = true;
    };
  };
}
