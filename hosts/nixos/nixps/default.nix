{
  lib,
  pkgs,
  user,
  ...
}: {
  imports = [
    ../../../profiles/nixos-desktop.nix
    ../../../modules/nixos/secureboot.nix
    ./hardware.nix
  ];

  networking.hostName = "nixps";

  time.timeZone = "America/Chicago";

  # Scale Zed for this machine's high-density display. The shared module keeps
  # its defaults for every other host.
  home-manager.users.${user.me.username}.programs.zed-editor.userSettings = {
    buffer_font_size = lib.mkForce 18;
    ui_font_size = 20;
  };

  environment.systemPackages = with pkgs; [
    wifitui
  ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  system.stateVersion = "26.05";
}
