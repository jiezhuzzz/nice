{pkgs, ...}: {
  # systemd-boot EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = 0; # Hold Space during boot for menu
  boot.loader.efi.canTouchEfiVariables = true;

  # Graphical boot splash with LUKS password prompt (Esc for text)
  boot.plymouth.enable = true;

  # Latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
