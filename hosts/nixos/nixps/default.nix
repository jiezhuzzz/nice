{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ../../../profiles/nixos-desktop.nix
    ../../../modules/nixos/secureboot.nix
    ./hardware.nix
  ];

  networking.hostName = "nixps";

  time.timeZone = "America/Chicago";

  environment.systemPackages = with pkgs; [
    wifitui
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  system.stateVersion = "26.05";
}
